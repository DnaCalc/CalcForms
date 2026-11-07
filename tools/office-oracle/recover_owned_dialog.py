"""End the recorded owned VBA error through public MSAA, without owner input."""
import argparse
import ctypes
from ctypes import wintypes
import json
import threading
from pathlib import Path
import uuid
import pythoncom
import win32com.client
import win32gui
import win32process
import win32service
from native_accessibility import accessible, check_hresult, Guid
from layout_corpus import ROOT


def recover(owner,window,output):
    proof=json.loads(owner.read_text(encoding='utf-8'))
    if proof['interactive'] or proof['excel_launches']!=1 or not proof['desktop'].startswith('CalcFormsOracle_'):
        raise ValueError('Owned private Excel required')
    if not output.resolve().is_relative_to(ROOT) or output.exists():
        raise ValueError('Fresh repository output required')
    desktop=win32service.OpenDesktop(proof['desktop'],0,False,511)
    try:
        desktop.SetThreadDesktop()
        pythoncom.CoInitialize()
        try:
            if win32process.GetWindowThreadProcessId(window)[1]!=proof['excel_pid'] or win32gui.GetWindowText(window)!='Microsoft Visual Basic':
                raise ValueError('Recorded dialog ownership/title differs')
            children=[]
            win32gui.EnumChildWindows(window,lambda hwnd,_:children.append(dict(hwnd=hwnd,text=win32gui.GetWindowText(hwnd),kind=win32gui.GetClassName(hwnd))),None)
            if not any("Run-time error '94'" in item['text'] for item in children):
                raise ValueError('Only the measured error 94 may be ended')
            button,=[item for item in children if item['kind']=='Button' and item['text']=='&End']
            iid=Guid.from_buffer_copy(uuid.UUID(str(pythoncom.IID_IDispatch)).bytes_le)
            pointer=ctypes.c_void_p()
            function=ctypes.OleDLL('oleacc').AccessibleObjectFromWindow
            function.argtypes=[wintypes.HWND,wintypes.DWORD,ctypes.POINTER(Guid),ctypes.POINTER(ctypes.c_void_p)]
            function.restype=ctypes.HRESULT
            check_hresult(function(button['hwnd'],0xfffffffc,ctypes.byref(iid),ctypes.byref(pointer)),'owned dialog MSAA')
            dispatch=win32com.client.Dispatch(pythoncom.ObjectFromAddress(pointer.value,pythoncom.IID_IDispatch))
            action=accessible(dispatch)
            try:
                action.invoke()
            finally:
                action.close()
            result=dict(schema='calcforms.owned_dialog_recovery.v1',excel_pid=proof['excel_pid'],excel_launches=1,
                        window=window,children=children,action='IAccessible.accDoDefaultAction on End',owner_input_or_focus_used=False)
            output.write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8',newline='\n')
            print(json.dumps(result))
        finally:
            pythoncom.CoUninitialize()
    finally:
        # This dedicated helper exits on the private desktop. It never switches
        # the input desktop, nor restores a desktop while COM owns helper windows.
        pass


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--owner',required=True,type=Path)
    parser.add_argument('--window',required=True,type=int)
    parser.add_argument('--out',required=True,type=Path)
    args=parser.parse_args()
    failures=[]
    def worker():
        try:
            recover(args.owner,args.window,args.out)
        except BaseException as error:
            failures.append(error)
    thread=threading.Thread(target=worker)
    thread.start()
    thread.join()
    if failures:
        raise failures[0]
