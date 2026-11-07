"""Observe IntegralHeight transitions in the existing hidden Excel."""
import argparse
import hashlib
import json
from pathlib import Path

from layout_corpus import ROOT
from owned_excel import run_owned_excel
from probe_source import validate_probe_source

SOURCE = '''Option Explicit
Private Function IntegralRow(ByVal C As MSForms.ListBox, ByVal StepName As String) As String
    C.ListIndex = 22
    C.TopIndex = 99
    IntegralRow = StepName & ";height=" & CStr(C.Height) & ";integral=" & CStr(C.IntegralHeight) & ";top=" & CStr(C.TopIndex) & vbLf
End Function
Public Function IntegralRun(ByVal Zoom As Long) As String
    On Error GoTo Failed
    Unload InventoryForm
    Load InventoryForm
    InventoryForm.Zoom = Zoom
    InventoryForm.Width = 450 * Zoom / 100
    InventoryForm.Height = 270 * Zoom / 100
    Dim C As MSForms.ListBox, S As String
    Set C = InventoryForm.Controls("PickList")
    S = "before-show;height=" & CStr(C.Height) & ";integral=" & CStr(C.IntegralHeight) & vbLf
    InventoryForm.Show vbModeless
    S = S & IntegralRow(C, "shown")
    C.IntegralHeight = True
    S = S & IntegralRow(C, "same-true")
    C.IntegralHeight = False
    S = S & IntegralRow(C, "false")
    C.IntegralHeight = False
    S = S & IntegralRow(C, "same-false")
    C.IntegralHeight = True
    S = S & IntegralRow(C, "true")
    C.IntegralHeight = True
    S = S & IntegralRow(C, "same-true-after-toggle")
    C.IntegralHeight = False
    C.Height = 80
    S = S & IntegralRow(C, "false-height-80")
    C.IntegralHeight = True
    S = S & IntegralRow(C, "true-height-80")
    C.Height = 72
    S = S & IntegralRow(C, "true-height-72")
    DoEvents
    S = S & IntegralRow(C, "after-doevents")
    InventoryForm.Hide
    InventoryForm.Show vbModeless
    S = S & IntegralRow(C, "reshow")
    InventoryForm.Hide
    IntegralRun = S
    Exit Function
Failed:
    IntegralRun = "CALCFORMS_NATIVE_ERROR:" & CStr(Err.Number) & ":" & Err.Description & vbLf & S
End Function
'''


def capture(owner, output):
    output = output.resolve()
    if not output.is_relative_to(ROOT) or output.exists():
        raise ValueError('Use a fresh repo-local output directory')
    output.mkdir(parents=True)
    validate_probe_source(SOURCE)
    (output / 'observer.bas').write_text(SOURCE, encoding='utf-8', newline='\n')
    fixture = ROOT / 'fixtures/workbooks/inventory/inventory.xlsm'

    def action(excel, proof, _):
        book = excel.Workbooks.Open(str(fixture), 0, True)
        try:
            module = book.VBProject.VBComponents.Add(1)
            module.Name = 'IntegralObserver'
            module.CodeModule.AddFromString(SOURCE)
            rows = []
            for zoom in (100, 150):
                result = excel.Run("'" + book.Name + "'!IntegralRun", zoom)
                rows.append(dict(zoom=zoom, result=result))
                if str(result).startswith('CALCFORMS_NATIVE_ERROR:'):
                    raise RuntimeError(result)
            return dict(schema='calcforms.native_integral_height.v1', owner=proof,
                        source_sha256=hashlib.sha256(SOURCE.encode()).hexdigest(),
                        workbook_sha256=hashlib.sha256(fixture.read_bytes()).hexdigest(), observations=rows)
        finally:
            book.Close(False)

    result = run_owned_excel(owner, action)
    (output / 'observations.json').write_text(json.dumps(result, indent=2) + '\n', encoding='utf-8', newline='\n')
    for row in result['observations']:
        print(row['zoom'], row['result'])


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--owner', required=True, type=Path)
    parser.add_argument('--out', required=True, type=Path)
    args = parser.parse_args()
    capture(args.owner, args.out)
