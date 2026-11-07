"""Recover the owned planner probe and retain each completed native step."""
import argparse
import json
from pathlib import Path
from author_planner import EVIDENCE, FIXTURE, SOURCE, digest
from owned_excel import run_owned_excel
from probe_source import validate_probe_source

FIXED=SOURCE


def observe(excel,owner,_):
    book=excel.Workbooks.Item('planner.xlsm')
    excel.Visible=False
    observer=book.VBProject.VBComponents.Item('PlannerObserver').CodeModule
    old=observer.Lines(1,observer.CountOfLines).replace('\r\n','\n').strip()
    historical=(EVIDENCE/'observer.bas').read_text(encoding='utf-8').strip()
    if old not in (historical,FIXED.strip()):
        raise ValueError('Owned observer contents differ')
    validate_probe_source(FIXED)
    observer.DeleteLines(1,observer.CountOfLines)
    observer.AddFromString(FIXED)
    (EVIDENCE/'observer-fixed.bas').write_text(FIXED,encoding='utf-8',newline='\n')
    macro=lambda name,*args:excel.Run("'"+book.Name+"'!"+name,*args)
    cases=[]
    result=dict(schema='calcforms.planner_workbook.v1',owner=owner,workbook_sha256=digest(FIXTURE/'planner.xlsm'),
                source_sha256=digest(FIXTURE/'form-code.bas'),entry_sha256=digest(FIXTURE/'entry.bas'),
                excel_version=str(excel.Version),excel_build=str(excel.Build),cases=cases)
    def save():
        (EVIDENCE/'partial.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8',newline='\n')
    try:
        for zoom in (100,150):
            initial=str(macro('PlannerPrepare',zoom))
            rows=[]
            cases.append(dict(zoom=zoom,observations=rows))
            def snapshot(step,error=0):
                row=dict(step=step,error=int(error),state=str(macro('PlannerState')),trace=str(macro('PlannerTrace')))
                rows.append(row)
                save()
                print(json.dumps(row),flush=True)
                if 'CALCFORMS_NATIVE_ERROR:' in row['state'] or 'CALCFORMS_NATIVE_ERROR:' in row['trace']:
                    raise ValueError(row)
            snapshot('initial')
            for step,name,value in [('day-five','DayPicker',5),('same-day','DayPicker',5),('hour-fourteen','HourPicker',14),('all-day','AllDay',-1),('same-all-day','AllDay',-1),('week','ViewTabs',1),('timed','AllDay',0),('last-day','DayPicker',30),('last-hour','HourPicker',23),('day-view','ViewTabs',0),('day-out-of-range','DayPicker',31),('hour-out-of-range','HourPicker',24)]:
                snapshot(step,macro('PlannerSet',name,value))
            macro('PlannerFinish')
        (EVIDENCE/'observations.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8',newline='\n')
        (FIXTURE/'authoring.json').write_text(json.dumps({key:value for key,value in result.items() if key!='cases'},indent=2)+'\n',encoding='utf-8',newline='\n')
        return result
    finally:
        book.Close(False)


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--owner',required=True,type=Path)
    args=parser.parse_args()
    print(json.dumps(run_owned_excel(args.owner,observe)))
