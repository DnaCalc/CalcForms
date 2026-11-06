"""Malformed native output and missing/reordered fragments must not earn parity."""
import copy
import hashlib
import struct
import unittest

from drawing_parity import text_geometry
from native_drawing import decode, records


def record(kind, payload=b''):
    return struct.pack('<II', kind, 8 + len(payload)) + payload


def emf(body):
    header = bytearray(88)
    struct.pack_into('<II', header, 0, 1, 88)
    struct.pack_into('<I', header, 40, 0x464d4520)
    rows = [bytes(header), *body, record(14)]
    struct.pack_into('<II', header, 48, sum(map(len, rows)), len(rows))
    return bytes(header) + b''.join(rows[1:])


class NativeDrawingTests(unittest.TestCase):
    def example(self):
        font = bytearray(92)
        struct.pack_into('<i', font, 0, -11)
        font[28:40] = 'Tahoma'.encode('utf-16-le')
        metrics = {hashlib.sha256(font).hexdigest(): dict(height=13, ascent=11, descent=2,
                                                        internal_leading=2, external_leading=0)}
        text = bytearray(88)
        struct.pack_into('<II', text, 0, 84, 88)
        struct.pack_into('<iiIII', text, 36, 4, 5, 2, 76, 4)
        struct.pack_into('<4i', text, 56, 2, 3, 14, 18)
        struct.pack_into('<I', text, 72, 80)
        text[76:80] = 'AB'.encode('utf-16-le')
        struct.pack_into('<2i', text, 80, 6, 7)
        return emf([record(82, struct.pack('<I', 1) + font), record(37, struct.pack('<I', 1)), bytes(text)]), metrics

    def test_baseline_and_cells_come_from_records_and_measured_font(self):
        raw, metrics = self.example()
        row, = decode(raw, metrics)
        self.assertEqual('AB', row['text'])
        self.assertEqual(16, row['baseline_px'])
        self.assertEqual([4, 10, 17], row['cell_edges_px'])
        self.assertEqual([2, 3, 14, 18], row['clip_px'])
        geometry = text_geometry(['AB'], [row])
        self.assertEqual([[1]], geometry['clipping_point'])
        self.assertEqual([[]], geometry['exact_line_breaks'])
        changed = copy.deepcopy(metrics)
        next(iter(changed.values()))['ascent'] = 10
        with self.assertRaisesRegex(ValueError, 'Invalid measured'):
            decode(raw, changed)
        with self.assertRaisesRegex(ValueError, 'Missing measured'):
            decode(raw, {})

    def test_truncated_records_and_bad_offsets_are_rejected(self):
        raw, metrics = self.example()
        with self.assertRaises(ValueError):
            records(raw[:-1])
        # Mutate the text record's string offset while retaining valid size.
        bad = bytearray(raw)
        text_start = sum(len(r) for _, r in records(raw)[:-2])
        struct.pack_into('<I', bad, text_start + 48, 999999)
        with self.assertRaisesRegex(ValueError, 'string offset'):
            decode(bytes(bad), metrics)

    def test_unsupported_glyph_indices_do_not_become_literal_text(self):
        raw, metrics = self.example()
        bad = bytearray(raw)
        text_start = sum(len(r) for _, r in records(raw)[:-2])
        struct.pack_into('<I', bad, text_start + 52, 0x14)
        with self.assertRaisesRegex(ValueError, 'Unsupported EMF text options'):
            decode(bytes(bad), metrics)

    def test_wrap_offsets_require_complete_ordered_literal_output(self):
        def run(text, y, x=0):
            return dict(text=text, baseline_px=y, origin_px=[x, y], clip_px=[0, 0, 100, 100],
                        cell_edges_px=list(range(x, x + len(text) + 1)))
        rows = [run('Long', 11), run('clipped', 11, 5), run('label', 11, 13), run('AgjpQy', 24)]
        result = text_geometry(['Long clipped label AgjpQy'], rows)
        self.assertEqual([[19]], result['exact_line_breaks'])
        self.assertEqual([11, 24], result['baseline'])
        self.assertIsNone(text_geometry(['Long clipped label AgjpQy'], rows[:-1]))
        self.assertIsNone(text_geometry(['Long clipped label AgjpQy'], [run('label', 11), run('Long clipped', 24)]))
        self.assertIsNone(text_geometry(['nonempty'], []))


if __name__ == '__main__':
    unittest.main()
