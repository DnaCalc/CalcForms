"""Author a genuine four-control planner in the one existing owned Excel."""
import argparse
import hashlib
import json
from pathlib import Path
from layout_corpus import ROOT
from owned_excel import run_owned_excel
from probe_source import validate_probe_source

FIXTURE=ROOT/'fixtures/workbooks/planner'
EVIDENCE=ROOT/'docs/evidence/W010_complete_msforms_object_model_parity/beads/oxforms-jbjp.126'
SOURCE='''Option Explicit
Public Function PlannerPrepare(ByVal Zoom As Long) As String
    On Error GoTo Failed
    Unload PlannerForm
    Load PlannerForm
    PlannerForm.Zoom = Zoom
    PlannerForm.Show vbModeless
    PlannerPrepare = PlannerForm.State()
    Exit Function
Failed:
    PlannerPrepare = "CALCFORMS_NATIVE_ERROR:" & CStr(Err.Number) & ":" & Err.Description
End Function
Public Function PlannerSet(ByVal ControlName As String, ByVal Value As Long) As Long
    On Error GoTo Failed
    If ControlName = "AllDay" Then
        PlannerForm.Controls(ControlName).Value = CBool(Value)
    Else
        PlannerForm.Controls(ControlName).Value = Value
    End If
    Exit Function
Failed:
    PlannerSet = Err.Number
End Function
Public Sub PlannerFinish()
    On Error GoTo Failed
    Unload PlannerForm
    Exit Sub
Failed:
    Err.Raise Err.Number, "PlannerFinish", Err.Description
End Sub
'''


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def author(excel,owner,_):
    target=FIXTURE/'planner.xlsm'
    if target.exists():
        raise ValueError('Do not overwrite a genuine workbook fixture')
    validate_probe_source(SOURCE)
    book=excel.Workbooks.Add()
    excel.Visible=False
    try:
        form=book.VBProject.VBComponents.Add(3)
        form.Name='PlannerForm'
        for name,value in [('Caption','CalcForms planner'),('Width',390),('Height',240)]:
            form.Properties.Item(name).Value=value
        for name,kind,x,y,width,height,caption in [('Title','Label',12,9,342,15,'Appointment planner'),('Summary','Label',12,153,342,21,'Ready'),('CloseButton','CommandButton',264,183,90,24,'Close')]:
            control=form.Designer.Controls.Add('Forms.'+kind+'.1',name,True)
            control.Left,control.Top,control.Width,control.Height=x,y,width,height
            control.Font.Name,control.Font.Size='Tahoma',8.25
            control.Caption=caption
            if name=='CloseButton':
                control.Cancel=True
        form.CodeModule.AddFromString((FIXTURE/'form-code.bas').read_text(encoding='utf-8'))
        entry=book.VBProject.VBComponents.Add(1)
        entry.Name='PlannerEntry'
        entry.CodeModule.AddFromString((FIXTURE/'entry.bas').read_text(encoding='utf-8'))
        book.SaveAs(str(target),52)
        form.Export(str(FIXTURE/'PlannerForm-qualified.frm'))
        workbook_hash=digest(target)
        observer=book.VBProject.VBComponents.Add(1)
        observer.Name='PlannerObserver'
        observer.CodeModule.AddFromString(SOURCE)
        macro=lambda name,*args:excel.Run("'"+book.Name+"'!"+name,*args)
        cases=[]
        for zoom in (100,150):
            initial=str(macro('PlannerPrepare',zoom))
            if initial.startswith('CALCFORMS_NATIVE_ERROR:'):
                raise ValueError(initial)
            rows=[]
            def snapshot(step,error=0):
                rows.append(dict(step=step,error=int(error),state=str(macro('PlannerState')),trace=str(macro('PlannerTrace'))))
            snapshot('initial')
            for step,name,value in [('day-five','DayPicker',5),('same-day','DayPicker',5),('hour-fourteen','HourPicker',14),('all-day','AllDay',-1),('same-all-day','AllDay',-1),('week','ViewTabs',1),('timed','AllDay',0),('last-day','DayPicker',30),('last-hour','HourPicker',23),('day-view','ViewTabs',0),('day-out-of-range','DayPicker',31),('hour-out-of-range','HourPicker',24)]:
                snapshot(step,macro('PlannerSet',name,value))
            cases.append(dict(zoom=zoom,observations=rows))
            macro('PlannerFinish')
        assert digest(target)==workbook_hash
        return dict(schema='calcforms.planner_workbook.v1',owner=owner,workbook_sha256=workbook_hash,
                    source_sha256=digest(FIXTURE/'form-code.bas'),entry_sha256=digest(FIXTURE/'entry.bas'),
                    excel_version=str(excel.Version),excel_build=str(excel.Build),cases=cases)
    finally:
        book.Close(False)


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--owner',required=True,type=Path)
    args=parser.parse_args()
    if (FIXTURE/'planner.xlsm').exists():
        parser.error('Do not overwrite the reviewed workbook or observer evidence')
    EVIDENCE.mkdir(parents=True,exist_ok=True)
    (EVIDENCE/'observer.bas').write_text(SOURCE,encoding='utf-8',newline='\n')
    result=run_owned_excel(args.owner,author)
    (EVIDENCE/'observations.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8',newline='\n')
    (FIXTURE/'authoring.json').write_text(json.dumps({key:value for key,value in result.items() if key!='cases'},indent=2)+'\n',encoding='utf-8',newline='\n')
    print(json.dumps(result))
