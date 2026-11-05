"""Read colour properties for the eight existing inputs using one already-owned Excel."""
import argparse
import json
from pathlib import Path

import pythoncom
import win32api

from layout_corpus import ROOT, load_corpus
from layout_measurements import native_controls
from forms_parity import TEXTLESS
from owned_excel import run_owned_excel
from workbook_comparison_session import WORKBOOK


def ole_colour(value):
    raw = int(value) & 0xffffffff
    resolved = win32api.GetSysColor(raw & 0xff) if raw & 0x80000000 else raw
    return dict(ole=raw, rgb=[resolved & 255, (resolved >> 8) & 255, (resolved >> 16) & 255])


def read_colours(form, facts, name):
    result = {}
    for path, c in native_controls(facts, name).items():
        current = form
        for part in path.split('.'):
            current = current.Controls.Item(part)
        properties = dict(enabled=bool(current.Enabled), fill=ole_colour(current.BackColor))
        if c['kind'] not in TEXTLESS:
            properties['text'] = ole_colour(current.ForeColor)
            colours = [ole_colour(0x80000011)['rgb'] if not current.Enabled else properties['text']['rgb']]
            if c['kind'] == 'ListBox' and current.Enabled:
                member = current._oleobj_.GetIDsOfNames('Selected')
                selected = [bool(current._oleobj_.Invoke(member, 0, pythoncom.DISPATCH_PROPERTYGET, 1, i))
                            for i in range(current.ListCount)]
                colours = ([properties['text']['rgb']] if not all(selected) else [])
                if any(selected):
                    colours.append(ole_colour(0x8000000e)['rgb'])
                properties['selected_rows'] = selected
            properties['effective_text_rgb'] = colours
        result[path] = properties
    return result


def capture(excel, owner, directory):
    results = []
    corpus = load_corpus()
    for path in sorted(directory.glob('*-qualification-*/comparison.json')):
        data = json.loads(path.read_text(encoding='utf-8'))
        form, zoom = data['form'], data['zoom']
        if form == 'greeter':
            book = excel.Workbooks.Item(WORKBOOK.name)
            if Path(book.FullName).resolve() != WORKBOOK.resolve():
                raise RuntimeError('Owned greeter path differs')
            prefix = "'" + book.Name + "'!"
            excel.Run(prefix + 'LayoutShow', zoom)
        else:
            book = excel.Workbooks.Item('layout-corpus.xlsm')
            if Path(book.FullName).resolve() != directory / 'corpus/layout-corpus.xlsm':
                raise RuntimeError('Owned corpus path differs')
            definition = next(f for f in corpus['forms'] if f['name'] == form)
            prefix = "'" + book.Name + "'!"
            excel.Run(prefix + 'LayoutShow', form, definition['width'], definition['height'], zoom)
        facts = excel.Run(prefix + 'LayoutFacts')
        if facts != data['excel_facts']:
            raise RuntimeError('Colour property read no longer matches captured native geometry')
        native = excel.Run(prefix + 'LayoutCaptureForm')
        results.append(dict(form=form, zoom=zoom, native=read_colours(native, facts, form)))
        native = None
        excel.Run(prefix + ('HideGreeter' if form == 'greeter' else 'LayoutHide'))
    return dict(schema='calcforms.native_colour_properties.v1', owner=owner, observations=results)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--owner', required=True, type=Path)
    parser.add_argument('--out', required=True, type=Path)
    args = parser.parse_args()
    if not args.out.resolve().is_relative_to(ROOT):
        raise ValueError('Colour evidence must stay in the repo')
    result = run_owned_excel(args.owner, capture)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(result, indent=2) + '\n', encoding='utf-8', newline='\n')
    print('Read native properties at both scales for four forms; no Excel launch or input desktop change.')


if __name__ == '__main__':
    main()
