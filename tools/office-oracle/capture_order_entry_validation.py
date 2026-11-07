"""Observe original BeforeUpdate veto and modeless reuse through owned-thread input."""
import argparse
import hashlib
import json
from pathlib import Path
import time
import pythoncom
from layout_corpus import ROOT
from owned_excel import run_owned_excel
from probe_source import validate_probe_source

FIXTURE=ROOT/'fixtures/workbooks/data-entry/order-entry.xlsm'
SOURCE='''Option Explicit
Private Declare PtrSafe Function GetFocus Lib "user32" () As LongPtr
Private Declare PtrSafe Function PostMessageW Lib "user32" (ByVal Window As LongPtr, ByVal Message As Long, ByVal WParam As LongPtr, ByVal LParam As LongPtr) As Long
Private Declare PtrSafe Function MapVirtualKeyW Lib "user32" (ByVal Code As Long, ByVal MapType As Long) As Long
Public Function OrderPrepare(ByVal Zoom As Long) As String
    On Error GoTo Failed
    Unload OrderEntryForm
    Load OrderEntryForm
    OrderEntryForm.Zoom = Zoom
    OpenOrderEntry
    OrderPrepare = OrderEntryForm.State()
    Exit Function
Failed:
    OrderPrepare = "CALCFORMS_NATIVE_ERROR:" & CStr(Err.Number) & ":" & Err.Description
End Function
Public Function OrderQueue(ByVal Code As Long, ByVal Character As Boolean) As String
    On Error GoTo Failed
    Dim Window As LongPtr
    Window = GetFocus()
    If Window = 0 Then Err.Raise 5, "OrderQueue", "No focused window in owned Excel"
    If Character Then
        If PostMessageW(Window, &H102, Code, 1) = 0 Then Err.Raise 5
    Else
        Dim Flags As Long
        Flags = 1 Or (MapVirtualKeyW(Code, 0) * 65536)
        If PostMessageW(Window, &H100, Code, Flags) = 0 Then Err.Raise 5
        If PostMessageW(Window, &H101, Code, Flags Or &HC0000000) = 0 Then Err.Raise 5
    End If
    OrderQueue = "queued"
    Exit Function
Failed:
    OrderQueue = "CALCFORMS_NATIVE_ERROR:" & CStr(Err.Number) & ":" & Err.Description
End Function
Public Function OrderFocus() As String
    On Error GoTo Failed
    OrderFocus = OrderEntryForm.ActiveControl.Name
    Exit Function
Failed:
    OrderFocus = "CALCFORMS_NATIVE_ERROR:" & CStr(Err.Number) & ":" & Err.Description
End Function
Public Sub OrderReload(ByVal Zoom As Long)
    On Error GoTo Failed
    Unload OrderEntryForm
    Load OrderEntryForm
    OrderEntryForm.Zoom = Zoom
    OpenOrderEntry
    Exit Sub
Failed:
    Err.Raise Err.Number, "OrderReload", Err.Description
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
        book=excel.Workbooks.Open(str(FIXTURE),0,True)
        excel.Visible=False
        try:
            observer=book.VBProject.VBComponents.Add(1)
            observer.Name='OrderValidationObserver'
            observer.CodeModule.AddFromString(SOURCE)
            def macro(name,*args):
                value=excel.Run("'"+book.Name+"'!"+name,*args)
                if isinstance(value,str) and value.startswith('CALCFORMS_NATIVE_ERROR:'):
                    raise ValueError(value)
                return value
            cases=[]
            for zoom in (100,150):
                macro('OrderPrepare',zoom)
                rows=[]
                cases.append(dict(zoom=zoom,observations=rows))
                def snapshot(step):
                    rows.append(dict(step=step,state=macro('OrderEntryState'),trace=macro('OrderEntryTrace'),focus=macro('OrderFocus')))
                    (output/'partial.json').write_text(json.dumps(cases,indent=2)+'\n',encoding='utf-8',newline='\n')
                def queue(step,code,character):
                    macro('OrderQueue',code,character)
                    time.sleep(.08)
                    pythoncom.PumpWaitingMessages()
                    snapshot(step)
                snapshot('initial')
                queue('type-x',120,True)
                queue('erase',8,False)
                if not rows[-1]['state'].startswith('name=;'):
                    raise ValueError('Native Backspace did not clear the edited name')
                queue('tab-veto',9,False)
                if rows[-1]['focus']!='NameInput' or not rows[-1]['trace'].endswith('|Name.BeforeUpdate|Name.Veto'):
                    raise ValueError('Native BeforeUpdate veto was not reached')
                queue('type-A',65,True)
                queue('type-d',100,True)
                queue('type-a',97,True)
                queue('tab-accept',9,False)
                queue('cancel',27,False)
                macro('OpenOrderEntry')
                snapshot('reshow')
                macro('OrderReload',zoom)
                snapshot('reload')
            return dict(schema='calcforms.order_entry_validation.v1',owner=proof,workbook_sha256=hashlib.sha256(FIXTURE.read_bytes()).hexdigest(),original_handlers_unchanged=True,qualified_validation=True,cases=cases)
        finally:
            book.Close(False)
    result=run_owned_excel(owner,action)
    (output/'observations.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8',newline='\n')
    print(json.dumps(result))


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--owner',required=True,type=Path)
    parser.add_argument('--out',required=True,type=Path)
    args=parser.parse_args()
    capture(args.owner,args.out)
