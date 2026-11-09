"""Round 14 native probe in one owned hidden Excel (macro calls only; no keyboard, pointer or focus).

.101  Font object on every font-bearing control and the UserForm (defaults, writes, coercions, copy).
.105  Geometry readback (Left/Top/Width/Height of a control and of a control in a Frame; UserForm
      Width/Height/InsideWidth/InsideHeight/Zoom), TabStop/TabIndex defaults, writes and renumbering
      in the form, in a Frame and in a MultiPage page, Tag/ControlTipText/HelpContextID.
.118  The ListBox run-8 viewport state rebuilt on a dynamically created ListBox, so the default
      Height 72 state can be compared between a designer control and a Controls.Add control.

Run through on-private-desktop.ps1 so the session root appears in Excel's command line.
"""
import argparse
import json
from pathlib import Path

from hidden_excel import hidden_excel
from round14_scripts import SCRIPTS

ENGINE = (Path(__file__).with_name('round14_engine.bas')).read_text(encoding='utf-8')

FORM = """Option Explicit
Private Sub UserForm_Initialize()
End Sub
"""

# Application.Run cannot take a long string: lines are buffered one call at a time.
DRIVER = """Option Explicit
Private Buffer As String
Private Last As String
Public Sub ClearBuffer()
    Buffer = ""
End Sub
Public Sub AddLine(ByVal S As String)
    Buffer = Buffer & S & vbLf
End Sub
Public Function RunBuffer() As String
    Dim Out As String
    Unload RForm
    Load RForm
    Out = RunScript(RForm, Buffer)
    Unload RForm
    Last = Out
    RunBuffer = CStr(Len(Out))
End Function
Public Function ResultPart(ByVal Start As Long) As String
    ResultPart = Mid(Last, Start, 8000)
End Function
"""

LIST_FORM = """Option Explicit
Private Sub UserForm_Initialize()
    Dim L As Object
    Set L = Me.Controls.Add("Forms.ListBox.1", "Choices")
    L.Left = 12: L.Top = 114: L.Width = 130: L.Height = 72
    L.AddItem "Alpha"
    L.AddItem "Beta"
    L.AddItem "Gamma"
End Sub
"""

# The run-8 sequence of capture_list_viewport.py on a ListBox created by Controls.Add.
LIST_MODULE = """Option Explicit
Private Function State() As String
    Dim C As Object
    Set C = DynForm.Controls("Choices")
    State = "index=" & CStr(C.ListIndex) & ";top=" & CStr(C.TopIndex) & ";count=" & CStr(C.ListCount) & ";height=" & CStr(C.Height)
End Function
Public Function DynPrepare(ByVal Zoom As Long, ByVal Count As Long, ByVal DoClear As Boolean, ByVal Show As Boolean) As String
    Dim C As Object, I As Long
    Load DynForm
    DynForm.Zoom = Zoom
    Set C = DynForm.Controls("Choices")
    If DoClear Then C.Clear
    C.Height = 72
    For I = 0 To Count - 1
        C.AddItem "Row " & CStr(I)
    Next
    C.ListIndex = 1
    C.TopIndex = 0
    If Show Then DynForm.Show vbModeless
    DynPrepare = State()
End Function
Public Function DynSet(ByVal Member As String, ByVal Value As Long) As String
    Dim C As Object
    Set C = DynForm.Controls("Choices")
    On Error Resume Next
    Select Case Member
        Case "top": C.TopIndex = Value
        Case "index": C.ListIndex = Value
        Case "height": C.Height = Value
    End Select
    DynSet = "err=" & CStr(Err.Number) & ";" & State()
End Function
Public Sub DynClose()
    On Error Resume Next
    DynForm.Hide
    Unload DynForm
End Sub
"""


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, required=True)
    parser.add_argument('--out', type=Path, required=True)
    args = parser.parse_args()
    result = dict(schema='calcforms.round14_native.v1', excel_launches=1, scripts={}, listbox_dynamic=[], errors={})
    try:
        with hidden_excel(args.root) as (excel, pid):
            result.update(excel_pid=pid, excel_version=str(excel.Version), excel_build=str(excel.Build),
                          visible_set=False)
            book = excel.Workbooks.Add()
            project = book.VBProject
            for name, code in (('RForm', FORM), ('DynForm', LIST_FORM)):
                form = project.VBComponents.Add(3)
                form.Name = name
                form.CodeModule.AddFromString(code)
            for name, code in (('Eng14', ENGINE), ('Drv14', DRIVER),
                               ('Dyn14', LIST_MODULE)):
                mod = project.VBComponents.Add(1)
                mod.Name = name
                mod.CodeModule.AddFromString(code)
            macro = lambda name, *a: excel.Run("'" + book.Name + "'!" + name, *a)
            for key, build in SCRIPTS.items():
                lines = build()
                try:
                    macro('ClearBuffer')
                    for line in lines:
                        macro('AddLine', line)
                    length = int(macro('RunBuffer'))
                    text = ''.join(str(macro('ResultPart', start)) for start in range(1, length + 1, 8000))
                    result['scripts'][key] = dict(lines=lines, result=text)
                    print(key, len(lines), 'lines', length, 'chars', flush=True)
                except Exception as error:
                    result['errors'][key] = repr(error)
                    try:
                        macro('ClearBuffer')
                    except Exception:
                        pass
            for count in (23, 30):
                for do_clear in (True, False):
                    for show in (True, False):
                        for zoom in (100,):
                            rows = [str(macro('DynPrepare', zoom, count, do_clear, show))]
                            for member, value in (('top', 16), ('top', 99), ('index', 7), ('index', 22), ('index', 29),
                                                  ('height', 120), ('top', 99), ('height', 30)):
                                rows.append(f'{member}={value}:' + str(macro('DynSet', member, value)))
                            macro('DynClose')
                            result['listbox_dynamic'].append(dict(count=count, clear=do_clear, show=show, zoom=zoom, rows=rows))
            book.Close(False)
    except Exception as error:
        result['errors']['fatal'] = repr(error)
        raise
    finally:
        args.out.write_text(json.dumps(result, indent=2, default=str) + '\n', encoding='utf-8')


if __name__ == '__main__':
    main()
