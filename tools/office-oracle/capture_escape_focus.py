"""Observe Escape validation/focus using messages queued inside owned Excel."""
import argparse
import hashlib
import json
from pathlib import Path
import time

import pythoncom

from layout_corpus import ROOT
from owned_excel import run_owned_excel
from probe_source import validate_probe_source

FIXTURE = ROOT / 'fixtures/workbooks/inventory'
HANDLERS = '''
Private Sub QtyInput_BeforeUpdate(ByVal Cancel As MSForms.ReturnBoolean)
    EscapeLog = EscapeLog & "|Qty.BeforeUpdate"
    If EscapeMode = "before_veto" Then Cancel.Value = True
End Sub
Private Sub QtyInput_AfterUpdate()
    EscapeLog = EscapeLog & "|Qty.AfterUpdate"
End Sub
Private Sub QtyInput_Exit(ByVal Cancel As MSForms.ReturnBoolean)
    EscapeLog = EscapeLog & "|Qty.Exit"
    If EscapeMode = "exit_veto" Then Cancel.Value = True
End Sub
Private Sub SubmitButton_Exit(ByVal Cancel As MSForms.ReturnBoolean)
    EscapeLog = EscapeLog & "|Submit.Exit"
End Sub
Private Sub CancelButton_Enter()
    EscapeLog = EscapeLog & "|Cancel.Enter"
End Sub
'''
GLOBALS = '''Option Explicit
Public EscapeMode As String
Public EscapeLog As String
'''
SOURCE = GLOBALS + '''
Public Function EscapePrepare(ByVal Mode As String, ByVal Zoom As Long) As String
    On Error GoTo Failed
    Unload InventoryForm
    EscapeMode = Mode
    Load InventoryForm
    InventoryForm.QtyInput.Text = ""
    InventoryForm.Zoom = Zoom
    InventoryForm.Width = 450 * Zoom / 100
    InventoryForm.Height = 270 * Zoom / 100
    InventoryForm.Show vbModeless
    If Mode = "submit_clean" Then
        InventoryForm.SubmitButton.SetFocus
    Else
        InventoryForm.QtyInput.SetFocus
    End If
    EscapeLog = ""
    EscapePrepare = EscapeObserve()
    Exit Function
Failed:
    EscapePrepare = "CALCFORMS_NATIVE_ERROR:" & CStr(Err.Number) & ":" & Err.Description
End Function
Public Function EscapeObserve() As String
    On Error GoTo Failed
    EscapeObserve = "focus=" & InventoryForm.ActiveControl.Name & ";visible=" & CStr(InventoryForm.Visible) & ";text=" & InventoryForm.QtyInput.Text & ";log=" & EscapeLog & ";trace=" & InventoryForm.Trace()
    Exit Function
Failed:
    EscapeObserve = "CALCFORMS_NATIVE_ERROR:" & CStr(Err.Number) & ":" & Err.Description
End Function
'''
INPUT = '''Option Explicit
Private Declare PtrSafe Function GetFocus Lib "user32" () As LongPtr
Private Declare PtrSafe Function PostMessageW Lib "user32" (ByVal Window As LongPtr, ByVal Message As Long, ByVal WParam As LongPtr, ByVal LParam As LongPtr) As Long
Public Function EscapeQueue(ByVal Character As Boolean) As String
    On Error GoTo Failed
    Dim Window As LongPtr
    Window = GetFocus()
    If Window = 0 Then Err.Raise 5, "EscapeQueue", "No control window on the owned Excel thread"
    If Character Then
        If PostMessageW(Window, &H102, 57, 1) = 0 Then Err.Raise 5
    Else
        If PostMessageW(Window, &H100, 27, &H10001) = 0 Then Err.Raise 5
        If PostMessageW(Window, &H101, 27, &HC0010001) = 0 Then Err.Raise 5
    End If
    EscapeQueue = "queued"
    Exit Function
Failed:
    EscapeQueue = "CALCFORMS_NATIVE_ERROR:" & CStr(Err.Number) & ":" & Err.Description
End Function
'''


def capture(owner, output):
    output = output.resolve()
    if not output.is_relative_to(ROOT) or output.exists():
        raise ValueError('Use a fresh repo-local output directory')
    output.mkdir(parents=True)
    for name, source in [('observer.bas', SOURCE), ('input.bas', INPUT)]:
        validate_probe_source(source)
        (output / name).write_text(source, encoding='utf-8', newline='\n')
    original = (FIXTURE / 'form-code.bas').read_text(encoding='utf-8')
    instrumented = original.replace('mTrace = mTrace & "|cancel"',
        'EscapeLog = EscapeLog & "|Cancel.Click"\n    mTrace = mTrace & "|cancel"') + HANDLERS
    (output / 'instrumented-form.bas').write_text(instrumented, encoding='utf-8', newline='\n')

    def action(excel, proof, _):
        book = excel.Workbooks.Open(str(FIXTURE / 'inventory.xlsm'), 0, True)
        try:
            form = book.VBProject.VBComponents.Item('InventoryForm').CodeModule
            form.DeleteLines(1, form.CountOfLines)
            form.AddFromString(instrumented)
            for name, source in [('EscapeObserver', SOURCE), ('EscapeInput', INPUT)]:
                module = book.VBProject.VBComponents.Add(1)
                module.Name = name
                module.CodeModule.AddFromString(source)
            prefix = "'" + book.Name + "'!"
            def macro(name, *args):
                result = excel.Run(prefix + name, *args)
                if str(result).startswith('CALCFORMS_NATIVE_ERROR:'):
                    raise RuntimeError(result)
                return result
            def settle():
                time.sleep(.08)
                pythoncom.PumpWaitingMessages()
            rows = []
            for zoom in (100, 150):
                for mode in ('submit_clean', 'field_clean', 'field_dirty', 'before_veto', 'exit_veto'):
                    macro('EscapePrepare', mode, zoom)
                    if mode in ('field_dirty', 'before_veto', 'exit_veto'):
                        macro('EscapeQueue', True)
                        settle()
                    before = macro('EscapeObserve')
                    macro('EscapeQueue', False)
                    settle()
                    rows.append(dict(zoom=zoom, mode=mode, before=before, after=macro('EscapeObserve')))
                    (output / 'partial.json').write_text(json.dumps(rows, indent=2) + '\n', encoding='utf-8', newline='\n')
            return dict(schema='calcforms.native_escape_focus.v1', owner=proof, observations=rows,
                        input='PostMessage queued inside Excel to GetFocus on its own private-desktop thread; no system input or owner focus',
                        workbook_sha256=hashlib.sha256((FIXTURE / 'inventory.xlsm').read_bytes()).hexdigest())
        finally:
            book.Close(False)

    result = run_owned_excel(owner, action)
    (output / 'observations.json').write_text(json.dumps(result, indent=2) + '\n', encoding='utf-8', newline='\n')
    print(json.dumps(result['observations'], indent=2))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--owner', required=True, type=Path)
    parser.add_argument('--out', required=True, type=Path)
    args = parser.parse_args()
    capture(args.owner, args.out)
