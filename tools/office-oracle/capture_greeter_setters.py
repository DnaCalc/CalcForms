"""Measure original greeter handlers through public setters and MSAA invocation."""
import argparse
import hashlib
import json
from pathlib import Path

from layout_corpus import ROOT
from native_accessibility import accessible
from owned_excel import run_owned_excel
from workbook_comparison_session import WORKBOOK


def capture(owner, output):
    output = output.resolve()
    if not output.is_relative_to(ROOT) or output.exists():
        raise ValueError('Use a fresh repository output directory')
    output.mkdir(parents=True)

    def action(excel, proof, _):
        book = excel.Workbooks.Item(WORKBOOK.name)
        macro = lambda name, *args: excel.Run("'" + book.Name + "'!" + name, *args)
        cases = []
        for zoom in (100, 150):
            macro('LayoutShow', zoom)
            form = macro('LayoutCaptureForm')
            controls = {name: form.Controls.Item(name) for name in ('Prompt', 'Output', 'InputName', 'Loud', 'Greet')}
            rows = []
            before = str(macro('GreeterState'))

            def row(control, step, member, selection=False):
                nonlocal before
                after = str(macro('GreeterState'))
                old_log, log = before.split(';')[0], after.split(';')[0]
                if not log.startswith(old_log):
                    raise ValueError('Original event log lost its prefix')
                value = getattr(controls[control], member)
                if isinstance(value, bool):
                    value = 'True' if value else 'False'
                result = dict(control=control, step=step, member=member, value=str(value),
                              before=before, after=after, events=[s for s in log[len(old_log):].split('|') if s])
                if selection:
                    text = controls['InputName']
                    result['selection'] = dict(start=int(text.SelStart), length=int(text.SelLength), text=str(text.SelText))
                rows.append(result)
                before = after

            try:
                controls['Prompt'].Caption = 'Name updated:'
                row('Prompt', 'caption', 'Caption')
                controls['Output'].Caption = '(changed)'
                row('Output', 'caption', 'Caption')
                controls['InputName'].Text = 'Lin'
                row('InputName', 'text', 'Text')
                controls['InputName'].SelStart = 1
                controls['InputName'].SelLength = 1
                row('InputName', 'select', 'Text', True)
                controls['InputName'].SelText = 'a'
                row('InputName', 'replace', 'Text', True)
                controls['Loud'].Value = True
                row('Loud', 'value', 'Value')
                controls['Loud'].Value = True
                row('Loud', 'same-value', 'Value')
                button = accessible(controls['Greet'])
                try:
                    button.invoke()
                finally:
                    button.close()
                row('Greet', 'invoke', 'Caption')
                cases.append(dict(zoom=zoom, observations=rows))
            finally:
                macro('HideGreeter')
        return dict(schema='calcforms.greeter_setters.v1', owner=proof,
                    workbook_sha256=hashlib.sha256(WORKBOOK.read_bytes()).hexdigest(),
                    original_handlers_unchanged=True, cases=cases)

    result = run_owned_excel(owner, action)
    (output / 'observations.json').write_text(json.dumps(result, indent=2) + '\n', encoding='utf-8', newline='\n')
    print(json.dumps(result))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--owner', required=True, type=Path)
    parser.add_argument('--out', required=True, type=Path)
    args = parser.parse_args()
    capture(args.owner, args.out)
