"""Observe separate public IntegralHeight/Height calls with native message draining."""
import argparse
import json
from pathlib import Path
from capture_integral_height import ROOT, run_owned_excel, validate_probe_source

SOURCE = '''Option Explicit
Private Function Snapshot() As String
    Dim C As MSForms.ListBox
    Set C = InventoryForm.Controls("PickList")
    Snapshot = "height=" & CStr(C.Height) & ";integral=" & CStr(C.IntegralHeight) & ";top=" & CStr(C.TopIndex)
End Function
Public Function IntegralPrepare(ByVal Zoom As Long) As String
    On Error GoTo Failed
    Unload InventoryForm
    Load InventoryForm
    InventoryForm.Zoom = Zoom
    InventoryForm.Show vbModeless
    InventoryForm.Controls("PickList").ListIndex = 22
    DoEvents
    IntegralPrepare = Snapshot()
    Exit Function
Failed:
    IntegralPrepare = "CALCFORMS_NATIVE_ERROR:" & CStr(Err.Number) & ":" & Err.Description
End Function
Public Function IntegralStep(ByVal Member As String, ByVal Value As Long) As String
    On Error GoTo Failed
    Dim C As MSForms.ListBox, S As String
    Set C = InventoryForm.Controls("PickList")
    Select Case Member
        Case "integral": C.IntegralHeight = CBool(Value)
        Case "height": C.Height = CSng(Value)
        Case "none"
        Case Else: Err.Raise 5
    End Select
    S = Snapshot()
    DoEvents
    S = S & vbLf & Snapshot()
    C.TopIndex = 99
    IntegralStep = S & vbLf & Snapshot()
    Exit Function
Failed:
    IntegralStep = "CALCFORMS_NATIVE_ERROR:" & CStr(Err.Number) & ":" & Err.Description
End Function
'''


def capture(owner, output):
    output = output.resolve()
    if not output.is_relative_to(ROOT) or output.exists():
        raise ValueError('Use a fresh repository output directory')
    output.mkdir(parents=True)
    validate_probe_source(SOURCE)
    (output/'observer.bas').write_text(SOURCE, encoding='utf-8', newline='\n')
    def action(excel, proof, _):
        book = excel.Workbooks.Open(str(ROOT/'fixtures/workbooks/inventory/inventory.xlsm'),0,True)
        try:
            module = book.VBProject.VBComponents.Add(1)
            module.Name = 'IntegralSteps'
            module.CodeModule.AddFromString(SOURCE)
            macro = lambda name,*args: str(excel.Run("'"+book.Name+"'!"+name,*args))
            cases=[]
            for zoom in (100,150):
                before = macro('IntegralPrepare',zoom)
                rows=[]
                for member,value in [('integral',1),('integral',0),('height',80),('integral',1),('height',72),('height',100),('integral',0),('height',80),('integral',1),('none',0)]:
                    result=macro('IntegralStep',member,value)
                    if result.startswith('CALCFORMS_NATIVE_ERROR:'):
                        raise ValueError(result)
                    rows.append(dict(member=member,value=value,result=result))
                cases.append(dict(zoom=zoom,before=before,observations=rows))
            return dict(schema='calcforms.integral_steps.v1',owner=proof,cases=cases)
        finally:
            book.Close(False)
    result=run_owned_excel(owner,action)
    (output/'observations.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8',newline='\n')
    print(json.dumps(result))


if __name__ == '__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--owner',required=True,type=Path)
    parser.add_argument('--out',required=True,type=Path)
    args=parser.parse_args()
    capture(args.owner,args.out)
