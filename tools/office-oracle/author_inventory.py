"""Author and observe a genuine inventory workbook in the existing owned Excel."""
import argparse
import hashlib
import json
from pathlib import Path

from layout_corpus import ROOT
from native_accessibility import post_key
from owned_excel import run_owned_excel
from probe_source import validate_probe_source
from workbook_comparison_session import windows, wait_for

FIXTURE = ROOT / 'fixtures/workbooks/inventory'
EVIDENCE = ROOT / 'docs/evidence/W010_complete_msforms_object_model_parity/beads/oxforms-jbjp.119'
OBSERVER = '''Option Explicit
Public Function Run8InventoryPrepare(ByVal Zoom As Long) As String
    On Error GoTo Failed
    Unload InventoryForm
    Load InventoryForm
    InventoryForm.Zoom = Zoom
    InventoryForm.Width = 450 * Zoom / 100
    InventoryForm.Height = 270 * Zoom / 100
    InventoryForm.Show vbModeless
    Run8InventoryPrepare = InventoryForm.ActiveControl.Name
    Exit Function
Failed:
    Run8InventoryPrepare = "CALCFORMS_NATIVE_ERROR:prepare:" & CStr(Err.Number) & ":" & Err.Description
End Function
Public Function Run8InventorySet(ByVal Member As String, ByVal Value As String) As String
    On Error GoTo Failed
    Select Case Member
        Case "quantity"
            InventoryForm.Controls("QtyInput").Text = Value
        Case "index"
            InventoryForm.Controls("PickList").ListIndex = CLng(Value)
        Case "focus"
            InventoryForm.Controls("PickList").SetFocus
        Case "show"
            InventoryForm.Show vbModeless
        Case Else
            Err.Raise 5, "InventoryProbe", "Unknown action"
    End Select
    Run8InventorySet = InventoryForm.State()
    Exit Function
Failed:
    Run8InventorySet = "CALCFORMS_NATIVE_ERROR:set:" & CStr(Err.Number) & ":" & Err.Description
End Function
Public Sub Run8InventoryFinish()
    On Error GoTo Failed
    Unload InventoryForm
    Exit Sub
Failed:
    Err.Raise Err.Number, "InventoryProbeFinish", Err.Description
End Sub
'''


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def write(path, data):
    path.write_text(json.dumps(data, indent=2) + '\n', encoding='utf-8', newline='\n')


def author(excel, owner, directory):
    target = FIXTURE / 'inventory.xlsm'
    if target.exists():
        raise ValueError('Do not overwrite the reviewed workbook fixture')
    validate_probe_source(OBSERVER)
    book = excel.Workbooks.Add()
    try:
        form = book.VBProject.VBComponents.Add(3)
        form.Name = 'InventoryForm'
        for name, value in [('Caption', 'CalcForms inventory'), ('Width', 450), ('Height', 270)]:
            form.Properties.Item(name).Value = value
        static = [('QtyLabel', 'Label', 12, 108, 144, 12, 'Quantity'),
                  ('QtyInput', 'TextBox', 12, 126, 144, 21, ''),
                  ('SelectedLabel', 'Label', 180, 24, 240, 21, 'Choose a part'),
                  ('StatusLabel', 'Label', 12, 190, 408, 21, 'Ready'),
                  ('SubmitButton', 'CommandButton', 180, 126, 108, 24, 'Submit'),
                  ('CancelButton', 'CommandButton', 306, 126, 108, 24, 'Cancel')]
        for name, kind, x, y, width, height, caption in static:
            control = form.Designer.Controls.Add('Forms.' + kind + '.1', name, True)
            control.Left, control.Top, control.Width, control.Height = x, y, width, height
            control.Font.Name, control.Font.Size = 'Tahoma', 8.25
            if kind != 'TextBox':
                control.Caption = caption
            if name == 'SubmitButton':
                control.Default = True
            if name == 'CancelButton':
                control.Cancel = True
        form.CodeModule.AddFromString((FIXTURE / 'form-code.bas').read_text(encoding='utf-8'))
        entry = book.VBProject.VBComponents.Add(1)
        entry.Name = 'InventoryEntry'
        entry.CodeModule.AddFromString((FIXTURE / 'entry.bas').read_text(encoding='utf-8'))
        book.SaveAs(str(target), 52)
        form.Export(str(FIXTURE / 'InventoryForm-qualified.frm'))
        workbook_hash = digest(target)
        prefix = "'" + book.Name + "'!"

        def run(member, *args):
            result = excel.Run(prefix + member, *args)
            if isinstance(result, str) and 'CALCFORMS_NATIVE_ERROR:' in result:
                raise ValueError(result)
            return result

        run('OpenInventory')
        initial = dict(initial_state=run('InventoryState'), initial_trace=run('InventoryTrace'))
        probe = book.VBProject.VBComponents.Add(1)
        probe.Name = 'Run8InventoryObserver'
        probe.CodeModule.AddFromString(OBSERVER)
        cases = []
        for zoom in (100, 150):
            initial_focus = run('Run8InventoryPrepare', zoom)
            root = wait_for(lambda: windows(owner['excel_pid'], title='CalcForms inventory'))[0]
            rows = []

            def snapshot(step):
                rows.append(dict(step=step, state=run('InventoryState'), trace=run('InventoryTrace')))

            def key(step, code):
                post_key(root, owner['excel_pid'], code)
                snapshot(step)

            def set_value(step, member, value):
                run('Run8InventorySet', member, value)
                snapshot(step)

            snapshot('initial')
            key('initial_submit', 13)
            run('Run8InventorySet', 'focus', '')
            key('page_down_1', 34)
            key('page_down_2', 34)
            set_value('zero_quantity', 'quantity', '0')
            key('reject_zero', 13)
            set_value('quantity_three', 'quantity', '3')
            key('submit_three', 13)
            set_value('last_part', 'index', '22')
            set_value('repeat_last', 'index', '22')
            set_value('invalid_text', 'quantity', '12a')
            key('reject_text', 13)
            set_value('quantity_two', 'quantity', '2')
            key('submit_two', 13)
            key('cancel', 27)
            set_value('reshow', 'show', '')
            cases.append(dict(zoom=zoom, initial_focus=initial_focus, observations=rows))
            run('Run8InventoryFinish')
        assert digest(target) == workbook_hash
        return dict(schema='calcforms.inventory_workbook.v1', excel_pid=owner['excel_pid'],
                    excel_launches=owner['excel_launches'], excel_version=excel.Version, excel_build=excel.Build,
                    workbook_sha256=workbook_hash, form_source_sha256=digest(FIXTURE / 'form-code.bas'),
                    entry_source_sha256=digest(FIXTURE / 'entry.bas'),
                    observer_sha256=hashlib.sha256(OBSERVER.encode('utf-8')).hexdigest(),
                    input='public VBA and per-window key messages on the private desktop; no owner input',
                    static_control_names=[row[0] for row in static], **initial, observations=cases)
    finally:
        book.Close(False)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--owner', type=Path, required=True)
    args = parser.parse_args()
    EVIDENCE.mkdir(parents=True, exist_ok=True)
    (EVIDENCE / 'observer.bas').write_text(OBSERVER, encoding='utf-8', newline='\n')
    result = run_owned_excel(args.owner, author)
    write(EVIDENCE / 'observations.json', result)
    write(FIXTURE / 'authoring.json', {key: value for key, value in result.items() if key != 'observations'})
    print(json.dumps(result, indent=2))
