"""Corroborate held-control errors inside Excel VBA, without cross-process readback."""
import argparse
import json
from pathlib import Path
from capture_greeter_setters import ROOT, WORKBOOK, run_owned_excel
from probe_source import validate_probe_source

SOURCE='''Option Explicit
Private Function ReadHeld(ByVal C As Object, ByVal Member As String) As String
    On Error GoTo Failed
    ReadHeld = CStr(CallByName(C, Member, VbGet)) & "~0"
    Exit Function
Failed:
    ReadHeld = "~" & CStr(Err.Number)
End Function
Public Function HeldReload(ByVal Zoom As Long) As String
    On Error GoTo Failed
    Unload WorkbookGreeter
    Dim F As WorkbookGreeter, T As MSForms.TextBox, P As MSForms.Label
    Dim O As MSForms.Label, B As MSForms.CommandButton, C As MSForms.CheckBox
    Set F = WorkbookGreeter
    F.Zoom = Zoom
    Set T = F.InputName
    Set P = F.Prompt
    Set O = F.Output
    Set B = F.Greet
    Set C = F.Loud
    T.Text = "Lin"
    Unload F
    Dim S As String
    S = "InputName~unload~" & ReadHeld(T, "Text") & vbLf
    S = S & "Prompt~unload~" & ReadHeld(P, "Caption") & vbLf
    S = S & "Output~unload~" & ReadHeld(O, "Caption") & vbLf
    S = S & "Greet~unload~" & ReadHeld(B, "Caption") & vbLf
    S = S & "Loud~unload~" & ReadHeld(C, "Value") & vbLf
    ShowGreeter
    S = S & "InputName~reload~" & ReadHeld(T, "Text") & vbLf
    S = S & "Prompt~reload~" & ReadHeld(P, "Caption") & vbLf
    S = S & "Output~reload~" & ReadHeld(O, "Caption") & vbLf
    S = S & "Greet~reload~" & ReadHeld(B, "Caption") & vbLf
    S = S & "Loud~reload~" & ReadHeld(C, "Value") & vbLf
    HeldReload = S
    Exit Function
Failed:
    HeldReload = "CALCFORMS_NATIVE_ERROR:" & CStr(Err.Number) & ":" & Err.Description
End Function
'''


def capture(owner,output):
    output=output.resolve()
    if not output.is_relative_to(ROOT) or output.exists():
        raise ValueError('Use a fresh repository output directory')
    output.mkdir(parents=True)
    validate_probe_source(SOURCE)
    (output/'observer.bas').write_text(SOURCE,encoding='utf-8',newline='\n')
    def action(excel,proof,_):
        book=excel.Workbooks.Item(WORKBOOK.name)
        module=book.VBProject.VBComponents.Add(1)
        module.Name='HeldReloadObserver'
        module.CodeModule.AddFromString(SOURCE)
        macro=lambda name,*args:excel.Run("'"+book.Name+"'!"+name,*args)
        try:
            cases=[]
            for zoom in (100,150):
                result=str(macro('HeldReload',zoom))
                if result.startswith('CALCFORMS_NATIVE_ERROR:'):
                    raise ValueError(result)
                cases.append(dict(zoom=zoom,result=result))
            return dict(schema='calcforms.native_held_reload.v1',owner=proof,cases=cases)
        finally:
            macro('HideGreeter')
            book.VBProject.VBComponents.Remove(module)
    result=run_owned_excel(owner,action)
    (output/'observations.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8',newline='\n')
    print(json.dumps(result['cases']))


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--owner',required=True,type=Path)
    parser.add_argument('--out',required=True,type=Path)
    args=parser.parse_args()
    capture(args.owner,args.out)
