"""Measure public drawing font sizes across control/container contexts."""
import argparse
import json
from pathlib import Path

from capture_native_drawing import capture_controls
from layout_corpus import ROOT, load_corpus
from layout_compare import geometry
from owned_excel import run_owned_excel
from workbook_comparison_session import windows


def capture(owner, output):
    output = output.resolve()
    if not output.is_relative_to(ROOT) or output.exists():
        raise ValueError('Use a fresh repo-local output directory')
    output.mkdir(parents=True)
    base = ROOT / 'docs/evidence/W010_complete_msforms_object_model_parity/beads/oxforms-jbjp.106/comparison.json'
    references = {(r['form'], r['zoom']): r for r in json.loads(base.read_text())['observations']}
    wanted = dict(LayoutCommon=['Prompt', 'InputName', 'Greet'],
                  LayoutSelection=['Unchecked', 'ToggleOff', 'Dropdown'],
                  LayoutContainers=['Group', 'Group.NestedInput', 'Group.NestedLabel', 'TabsControl'])
    definitions = {f['name']: f for f in load_corpus()['forms']}

    def action(excel, proof, _):
        book = excel.Workbooks.Item('layout-corpus.xlsm')
        prefix = "'" + book.Name + "'!"
        rows = []
        try:
            for name, names in wanted.items():
                definition = definitions[name]
                for zoom in (100, 150):
                    excel.Run(prefix + 'LayoutShow', name, definition['width'], definition['height'], zoom)
                    form = excel.Run(prefix + 'LayoutCaptureForm')
                    root, = windows(proof['excel_pid'], definition['caption'])
                    controls = {}
                    for path in names:
                        control = form
                        for part in path.split('.'):
                            control = control.Controls.Item(part)
                        controls[path] = control
                    for size in (7, 8, 8.25, 8.5, 9, 10, 11, 12):
                        for control in controls.values():
                            control.Font.Size = size
                        directory = output / f'{name}-{zoom}-{str(size).replace(".", "_")}'
                        directory.mkdir()
                        row = dict(references[name, zoom])
                        row['excel'] = dict(geometry=geometry(root))
                        row['measurements'] = dict(controls=[c for c in row['measurements']['controls'] if c['name'] in names])
                        drawing = capture_controls(excel, prefix, row, directory)
                        rows.append(dict(form=name, zoom=zoom, requested_font_size=size,
                                         returned_font_sizes={path: float(c.Font.Size) for path, c in controls.items()},
                                         drawings=drawing))
                        (output / 'partial.json').write_text(json.dumps(rows, indent=2) + '\n', encoding='utf-8', newline='\n')
                    for control in controls.values():
                        control.Font.Size = 8.25
                    controls.clear()
                    form = None
                    excel.Run(prefix + 'LayoutHide')
            return dict(schema='calcforms.native_font_context.v1', owner=proof,
                        method='public control OleDraw records and GDI font metrics; no system input', observations=rows)
        finally:
            excel.Run(prefix + 'LayoutHide')

    result = run_owned_excel(owner, action)
    (output / 'observations.json').write_text(json.dumps(result, indent=2) + '\n', encoding='utf-8', newline='\n')
    print('Captured', len(result['observations']), 'font-size/context cases in the same Excel')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--owner', required=True, type=Path)
    parser.add_argument('--out', required=True, type=Path)
    args = parser.parse_args()
    capture(args.owner, args.out)
