"""Read genuine greeter lifecycle values entirely within owned Excel VBA."""
import argparse
import hashlib
import json
from pathlib import Path
from capture_greeter_setters import ROOT, WORKBOOK, run_owned_excel
from capture_held_reload import SOURCE as HELD
from probe_source import validate_probe_source

SOURCE=HELD.split('Public Function HeldReload',1)[0]+'''Private Function LifeSnapshot(ByVal StepName As String, ByVal F As WorkbookGreeter, ByVal Loaded As Boolean, ByVal P As Object, ByVal O As Object, ByVal T As Object, ByVal C As Object, ByVal B As Object) As String
    Dim S As String
    S = "@" & StepName & "~~" & vbLf
    If Loaded Then S = "@" & StepName & "~" & CStr(F.Visible) & "~" & F.State() & vbLf
    S = S & "Prompt~Caption~" & ReadHeld(P, "Caption") & vbLf
    S = S & "Output~Caption~" & ReadHeld(O, "Caption") & vbLf
    S = S & "InputName~Text~" & ReadHeld(T, "Text") & vbLf
    S = S & "Loud~Value~" & ReadHeld(C, "Value") & vbLf
    S = S & "Greet~Caption~" & ReadHeld(B, "Caption") & vbLf
    LifeSnapshot = S
End Function
Public Function GreeterLifeRun(ByVal Zoom As Long) As String
    On Error GoTo Failed
    Unload WorkbookGreeter
    Dim F As WorkbookGreeter, G As WorkbookGreeter
    Dim T As MSForms.TextBox, P As MSForms.Label, O As MSForms.Label
    Dim B As MSForms.CommandButton, C As MSForms.CheckBox
    Set F = WorkbookGreeter
    F.Zoom = Zoom
    F.Show vbModeless
    Set T = F.InputName
    Set P = F.Prompt
    Set O = F.Output
    Set B = F.Greet
    Set C = F.Loud
    T.Text = "Lin"
    C.Value = True
    O.Caption = "(modified)"
    Dim S As String
    S = LifeSnapshot("modified", F, True, P, O, T, C, B)
    F.Hide
    S = S & LifeSnapshot("hidden", F, True, P, O, T, C, B)
    F.Show vbModeless
    S = S & LifeSnapshot("shown", F, True, P, O, T, C, B)
    Unload F
    S = S & LifeSnapshot("unloaded-held-controls", F, False, P, O, T, C, B)
    Set G = WorkbookGreeter
    G.Show vbModeless
    S = S & LifeSnapshot("fresh-default", G, True, G.Prompt, G.Output, G.InputName, G.Loud, G.Greet)
    S = S & LifeSnapshot("old-controls-after-reload", F, False, P, O, T, C, B)
    GreeterLifeRun = S
    Exit Function
Failed:
    GreeterLifeRun = "CALCFORMS_NATIVE_ERROR:" & CStr(Err.Number) & ":" & Err.Description
End Function
'''


def parse(text):
    rows=[]
    for line in text.splitlines():
        if line.startswith('@'):
            step,visible,state=line[1:].split('~',2)
            rows.append(dict(step=step,values={},form_visible=None if not visible else visible=='True',state=state or None))
        else:
            name,member,value,error=line.split('~')
            rows[-1]['values'][name]=dict(member=member,value=value if int(error)==0 else None,error=int(error))
    if len(rows)!=6 or any(len(row['values'])!=5 for row in rows):
        raise ValueError('Incomplete native lifecycle rows')
    return rows


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
        module.Name='GreeterInProcessLifetime'
        module.CodeModule.AddFromString(SOURCE)
        macro=lambda name,*args:excel.Run("'"+book.Name+"'!"+name,*args)
        try:
            cases=[]
            for zoom in (100,150):
                result=str(macro('GreeterLifeRun',zoom))
                if result.startswith('CALCFORMS_NATIVE_ERROR:'):
                    raise ValueError(result)
                cases.append(dict(zoom=zoom,result=result,observations=parse(result)))
            return dict(schema='calcforms.greeter_lifecycle.v1',owner=proof,workbook_sha256=hashlib.sha256(WORKBOOK.read_bytes()).hexdigest(),original_handlers_unchanged=True,input='in-process VBA; typed held controls',cases=cases)
        finally:
            macro('HideGreeter')
            book.VBProject.VBComponents.Remove(module)
    result=run_owned_excel(owner,action)
    (output/'observations.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8',newline='\n')
    print('Recorded six lifecycle stages in VBA at both scales')


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--owner',required=True,type=Path)
    parser.add_argument('--out',required=True,type=Path)
    args=parser.parse_args()
    capture(args.owner,args.out)
