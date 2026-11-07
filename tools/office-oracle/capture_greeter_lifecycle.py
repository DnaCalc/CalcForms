"""Measure retained control values across genuine greeter Hide/Show/Unload."""
import argparse
import hashlib
import json
import pywintypes
from pathlib import Path
from capture_greeter_setters import ROOT, WORKBOOK, accessible, run_owned_excel
from probe_source import validate_probe_source

SOURCE='''Option Explicit
Public Sub GreeterUnloadDefault()
    On Error GoTo Failed
    Unload WorkbookGreeter
    Exit Sub
Failed:
    Err.Raise Err.Number, "GreeterUnloadDefault", Err.Description
End Sub
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
        module.Name='GreeterLifetimeObserver'
        module.CodeModule.AddFromString(SOURCE)
        macro=lambda name,*args:excel.Run("'"+book.Name+"'!"+name,*args)
        cases=[]
        try:
            for zoom in (100,150):
                macro('LayoutShow',zoom)
                form=macro('LayoutCaptureForm')
                controls={name:form.Controls.Item(name) for name in ('Prompt','Output','InputName','Loud','Greet')}
                controls['InputName'].Text='Lin'
                controls['Loud'].Value=True
                button=accessible(controls['Greet'])
                try:
                    button.invoke()
                finally:
                    button.close()
                rows=[]
                def snapshot(step,current,loaded):
                    values={}
                    for name,control in current.items():
                        member='Text' if name=='InputName' else 'Value' if name=='Loud' else 'Caption'
                        try:
                            value=getattr(control,member)
                            if isinstance(value,bool):
                                value='True' if value else 'False'
                            values[name]=dict(member=member,value=str(value),error=0)
                        except pywintypes.com_error as error:
                            values[name]=dict(member=member,value=None,error=error.hresult)
                    rows.append(dict(step=step,values=values,form_visible=bool(form.Visible) if loaded else None,state=str(macro('GreeterState')) if loaded else None))
                snapshot('modified',controls,True)
                macro('HideGreeter')
                snapshot('hidden',controls,True)
                macro('ShowGreeter')
                snapshot('shown',controls,True)
                macro('GreeterUnloadDefault')
                snapshot('unloaded-held-controls',controls,False)
                macro('LayoutShow',zoom)
                form=macro('LayoutCaptureForm')
                fresh={name:form.Controls.Item(name) for name in controls}
                snapshot('fresh-default',fresh,True)
                snapshot('old-controls-after-reload',controls,False)
                cases.append(dict(zoom=zoom,observations=rows))
            return dict(schema='calcforms.greeter_lifecycle.v1',owner=proof,workbook_sha256=hashlib.sha256(WORKBOOK.read_bytes()).hexdigest(),original_handlers_unchanged=True,cases=cases)
        finally:
            macro('HideGreeter')
            book.VBProject.VBComponents.Remove(module)
    result=run_owned_excel(owner,action)
    (output/'observations.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8',newline='\n')
    print('Recorded six lifecycle stages at both scales')


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--owner',required=True,type=Path)
    parser.add_argument('--out',required=True,type=Path)
    args=parser.parse_args()
    capture(args.owner,args.out)
