"""Read public MS-EMF drawing records emitted by native MSForms OleDraw.

This is black-box rendering output, not Office binary inspection. The raw
metafile and measured GDI font metrics remain replay inputs. Unsupported text
encodings, mappings and alignment fail explicitly rather than guessing geometry.
"""
from __future__ import annotations

import copy
import hashlib
import struct


def records(raw):
    result, offset = [], 0
    while offset < len(raw):
        if len(raw) - offset < 8:
            raise ValueError('Truncated EMF record header')
        kind, size = struct.unpack_from('<II', raw, offset)
        if size < 8 or size % 4 or offset + size > len(raw):
            raise ValueError('Invalid EMF record size')
        result.append((kind, raw[offset:offset + size]))
        offset += size
    if not result or result[0][0] != 1 or result[-1][0] != 14:
        raise ValueError('EMF requires header and EOF records')
    if len(result[0][1]) < 88 or struct.unpack_from('<I', result[0][1], 40)[0] != 0x464d4520:
        raise ValueError('Invalid enhanced metafile signature')
    if struct.unpack_from('<II', result[0][1], 48) != (len(raw), len(result)):
        raise ValueError('EMF header byte/record count differs')
    return result


def font_metrics(raw):
    """Measure selected public LOGFONTs on Windows; no Office process required."""
    import ctypes
    from ctypes import wintypes as w
    gdi = ctypes.WinDLL('gdi32', use_last_error=True)
    gdi.CreateCompatibleDC.argtypes = [w.HDC]
    gdi.CreateCompatibleDC.restype = w.HDC
    gdi.CreateFontIndirectW.argtypes = [ctypes.c_void_p]
    gdi.CreateFontIndirectW.restype = w.HANDLE
    gdi.SelectObject.argtypes = [w.HDC, w.HANDLE]
    gdi.SelectObject.restype = w.HANDLE
    gdi.GetTextMetricsW.argtypes = [w.HDC, ctypes.c_void_p]
    gdi.GetTextMetricsW.restype = w.BOOL
    gdi.DeleteObject.argtypes = [w.HANDLE]
    gdi.DeleteDC.argtypes = [w.HDC]
    dc = gdi.CreateCompatibleDC(None)
    if not dc:
        raise OSError('CreateCompatibleDC failed')
    result = {}
    try:
        for kind, record in records(raw):
            if kind != 82:
                continue
            logfont = record[12:104]
            if len(logfont) != 92:
                raise ValueError('Truncated LOGFONTW')
            key = hashlib.sha256(logfont).hexdigest()
            if key in result:
                continue
            font = gdi.CreateFontIndirectW(ctypes.create_string_buffer(logfont))
            if not font:
                raise OSError('CreateFontIndirectW failed')
            previous = gdi.SelectObject(dc, font)
            try:
                metric = ctypes.create_string_buffer(64)
                if not gdi.GetTextMetricsW(dc, metric):
                    raise OSError('GetTextMetricsW failed')
                height, ascent, descent, internal, external = struct.unpack_from('<5i', metric.raw)
                result[key] = dict(height=height, ascent=ascent, descent=descent,
                                   internal_leading=internal, external_leading=external)
            finally:
                gdi.SelectObject(dc, previous)
                gdi.DeleteObject(font)
    finally:
        gdi.DeleteDC(dc)
    return result


def decode(raw, metrics):
    fonts, saved, output = {}, [], []
    state = dict(font=None, align=0, colour=0, window=[0, 0], viewport=[0, 0],
                 window_extent=[1, 1], viewport_extent=[1, 1])

    def point(x, y):
        return [(v - state['window'][i]) * state['viewport_extent'][i] / state['window_extent'][i]
                + state['viewport'][i] for i, v in enumerate((x, y))]

    for index, (kind, record) in enumerate(records(raw)):
        if kind == 82:
            handle = struct.unpack_from('<I', record, 8)[0]
            logfont = record[12:104]
            key = hashlib.sha256(logfont).hexdigest()
            if key not in metrics:
                raise ValueError('Missing measured GDI font metrics')
            tm = metrics[key]
            if tm['height'] != tm['ascent'] + tm['descent'] or min(tm.values()) < 0:
                raise ValueError('Invalid measured GDI font metrics')
            fonts[handle] = dict(key=key, face=logfont[28:92].decode('utf-16-le').split('\0')[0], **tm)
        elif kind == 37:
            handle = struct.unpack_from('<I', record, 8)[0]
            if handle in fonts:
                state['font'] = fonts[handle]
            elif handle & 0x80000000:
                # Stock pens/brushes are harmless. Stock fonts are unsupported.
                if handle & 0x7fffffff in (10, 11, 12, 13, 14, 16, 17):
                    state['font'] = None
        elif kind == 40:
            fonts.pop(struct.unpack_from('<I', record, 8)[0], None)
        elif kind == 22:
            state['align'] = struct.unpack_from('<I', record, 8)[0]
        elif kind == 24:
            state['colour'] = struct.unpack_from('<I', record, 8)[0]
        elif kind == 33:
            saved.append(copy.deepcopy(state))
        elif kind == 34:
            relative = struct.unpack_from('<i', record, 8)[0]
            if relative >= 0 or -relative > len(saved):
                raise ValueError('Unsupported EMF DC restore')
            state = saved[relative]
            del saved[relative:]
        elif kind in (9, 10, 11, 12):
            member = {9: 'window_extent', 10: 'window', 11: 'viewport_extent', 12: 'viewport'}[kind]
            state[member] = list(struct.unpack_from('<2i', record, 8))
            if 'extent' in member and 0 in state[member]:
                raise ValueError('Zero EMF mapping extent')
        elif kind in (35, 36):
            transform = struct.unpack_from('<6f', record, 8)
            if transform != (1, 0, 0, 1, 0, 0):
                raise ValueError('Unsupported EMF world transform')
        elif kind == 17 and struct.unpack_from('<I', record, 8)[0] not in (1, 8):
            raise ValueError('Unsupported EMF mapping mode')
        elif kind in (83, 96, 97, 108):
            raise ValueError('Unsupported EMF text record')
        elif kind == 84:
            if len(record) < 76:
                raise ValueError('Truncated EMF text record')
            x, y, count, offset, options = struct.unpack_from('<iiIII', record, 36)
            if count == 0:
                continue  # Opaque rectangle output has no text geometry.
            if options & ~0x6:  # Only Unicode text with optional opaque/clipped rectangle.
                raise ValueError('Unsupported EMF text options')
            if offset < 76 or offset + count * 2 > len(record):
                raise ValueError('Invalid EMF text string offset')
            text = record[offset:offset + count * 2].decode('utf-16-le')
            if len(text) != count:
                raise ValueError('Supplementary text needs UTF-16 offset support')
            dx_offset = struct.unpack_from('<I', record, 72)[0]
            if dx_offset < 76 or dx_offset + count * 4 > len(record):
                raise ValueError('Missing/invalid EMF character advances')
            dx = list(struct.unpack_from('<' + str(count) + 'i', record, dx_offset))
            font = state['font']
            if font is None or state['align'] & ~0x1e:
                raise ValueError('Unsupported EMF font or text alignment')
            vertical = state['align'] & 0x18
            baseline = y if vertical == 0x18 else y - font['descent'] if vertical == 8 else y + font['ascent']
            horizontal = state['align'] & 6
            if horizontal not in (0, 2, 6):
                raise ValueError('Unsupported EMF horizontal alignment')
            start = x - (sum(dx) if horizontal == 2 else sum(dx) / 2 if horizontal == 6 else 0)
            cells, cursor = [], start
            for advance in dx:
                cells.append(point(cursor, baseline)[0])
                cursor += advance
            cells.append(point(cursor, baseline)[0])
            clip = list(struct.unpack_from('<4i', record, 56)) if options & 4 else None
            output.append(dict(record=index, text=text, reference_px=point(x, y),
                               baseline_px=point(start, baseline)[1], origin_px=point(start, baseline),
                               clip_px=point(*clip[:2]) + point(*clip[2:]) if clip else None,
                               cell_edges_px=cells, colour=state['colour'], font=font))
    return output


def observation(path):
    raw = path.read_bytes()
    metrics = font_metrics(raw)
    return dict(file=path.name, sha256=hashlib.sha256(raw).hexdigest(),
                method='MSForms public OleDraw / IViewObject; EMR_EXTTEXTOUTW and measured GDI font metrics',
                font_metrics=metrics, text=decode(raw, metrics))
