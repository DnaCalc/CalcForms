"""Author a real forms workbook in the existing private Excel, without owner input."""
import argparse
import hashlib
import json
from pathlib import Path

from layout_corpus import ROOT
from owned_excel import run_owned_excel

FIXTURE = ROOT / 'fixtures/workbooks/data-entry'


def author(excel, owner, directory):
    target = FIXTURE / 'order-entry.xlsm'
    if target.exists():
        raise ValueError('Do not overwrite the reviewed workbook fixture')
    book = excel.Workbooks.Add()
    form = book.VBProject.VBComponents.Add(3)
    form.Name = 'OrderEntryForm'
    for property, value in [('Caption', 'CalcForms order entry'), ('Width', 426), ('Height', 390)]:
        form.Properties.Item(property).Value = value
    designer = form.Designer
    static = [('NameLabel', 'Label', 12, 4, 186, 12, 'Name'),
              ('NameInput', 'TextBox', 12, 18, 186, 21, ''),
              ('StatusLabel', 'Label', 12, 294, 390, 18, 'Ready'),
              ('SaveButton', 'CommandButton', 228, 324, 84, 24, 'Save'),
              ('CancelButton', 'CommandButton', 318, 324, 84, 24, 'Cancel')]
    for name, kind, x, y, w, h, caption in static:
        control = designer.Controls.Add('Forms.' + kind + '.1', name, True)
        control.Left, control.Top, control.Width, control.Height = x, y, w, h
        control.Font.Name, control.Font.Size = 'Tahoma', 8.25
        if kind != 'TextBox':
            control.Caption = caption
        if name == 'SaveButton':
            control.Default = True
        if name == 'CancelButton':
            control.Cancel = True
    form.CodeModule.AddFromString((FIXTURE / 'form-code.bas').read_text(encoding='utf-8'))
    entry = book.VBProject.VBComponents.Add(1)
    entry.Name = 'OrderEntry'
    entry.CodeModule.AddFromString((FIXTURE / 'entry.bas').read_text(encoding='utf-8'))
    book.SaveAs(str(target), 52)
    form.Export(str(FIXTURE / 'OrderEntryForm-qualified.frm'))
    prefix = "'" + book.Name + "'!"
    excel.Run(prefix + 'OpenOrderEntry')
    state, trace = excel.Run(prefix + 'OrderEntryState'), excel.Run(prefix + 'OrderEntryTrace')
    if state.startswith('CALCFORMS_NATIVE_ERROR:'):
        raise RuntimeError(state)
    return dict(schema='calcforms.data_entry_authoring.v1', owner=owner,
                workbook_sha256=hashlib.sha256(target.read_bytes()).hexdigest(),
                static_control_names=[row[0] for row in static],
                excel_version=excel.Version, excel_build=excel.Build, initial_state=state, initial_trace=trace)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--owner', required=True, type=Path)
    args = parser.parse_args()
    result = run_owned_excel(args.owner, author)
    path = FIXTURE / 'authoring.json'
    path.write_text(json.dumps(result, indent=2) + '\n', encoding='utf-8', newline='\n')
    print(json.dumps(result))


if __name__ == '__main__':
    main()
