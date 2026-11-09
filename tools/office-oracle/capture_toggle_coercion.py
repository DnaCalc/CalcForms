"""Measure native ToggleButton/CheckBox/OptionButton Value coercion in one owned hidden Excel.

Run through on-private-desktop.ps1; the session root must appear in Excel's command line.
Never touches input, focus, Trust Center or registry. Launches exactly one Excel and stops it.
"""
import argparse
import json
import subprocess
from pathlib import Path

import pythoncom

from workbook_comparison_session import EXCEL, native_excel, wait_for

FORM = '''Option Explicit
Public Log As String
Public WithEvents T As MSForms.ToggleButton
Public WithEvents C As MSForms.CheckBox
Public WithEvents O As MSForms.OptionButton
Private Function V(x As Variant) As String
    If IsNull(x) Then
        V = "Null"
    ElseIf IsEmpty(x) Then
        V = "Empty"
    Else
        V = TypeName(x) & "=" & CStr(x)
    End If
End Function
Private Sub UserForm_Initialize()
    Set T = Me.Controls.Add("Forms.ToggleButton.1", "T")
    Set C = Me.Controls.Add("Forms.CheckBox.1", "C")
    Set O = Me.Controls.Add("Forms.OptionButton.1", "O")
    T.Left = 6: T.Top = 6: T.Width = 80: T.Height = 24
    C.Left = 6: C.Top = 40: C.Width = 80: C.Height = 24
    O.Left = 6: O.Top = 74: O.Width = 80: O.Height = 24
End Sub
Private Sub T_Change(): Log = Log & "T.Change(" & V(T.Value) & ");": End Sub
Private Sub T_Click(): Log = Log & "T.Click(" & V(T.Value) & ");": End Sub
Private Sub C_Change(): Log = Log & "C.Change(" & V(C.Value) & ");": End Sub
Private Sub C_Click(): Log = Log & "C.Click(" & V(C.Value) & ");": End Sub
Private Sub O_Change(): Log = Log & "O.Change(" & V(O.Value) & ");": End Sub
Private Sub O_Click(): Log = Log & "O.Click(" & V(O.Value) & ");": End Sub
'''

MODULE = '''Option Explicit
Private Function V(x As Variant) As String
    If IsNull(x) Then
        V = "Null"
    ElseIf IsEmpty(x) Then
        V = "Empty"
    Else
        V = TypeName(x) & "=" & CStr(x)
    End If
End Function
Private Function MakeVal(ByVal Code As Long) As Variant
    Select Case Code
        Case 0: MakeVal = CInt(-1)
        Case 1: MakeVal = CLng(-1)
        Case 2: MakeVal = CInt(0)
        Case 3: MakeVal = CLng(0)
        Case 4: MakeVal = CInt(1)
        Case 5: MakeVal = CLng(1)
        Case 6: MakeVal = CInt(2)
        Case 7: MakeVal = CLng(100)
        Case 8: MakeVal = CByte(1)
        Case 9: MakeVal = CSng(1.5)
        Case 10: MakeVal = CDbl(0.4)
        Case 11: MakeVal = CDbl(0.6)
        Case 12: MakeVal = CCur(1)
        Case 13: MakeVal = "True"
        Case 14: MakeVal = "False"
        Case 15: MakeVal = "0"
        Case 16: MakeVal = "1"
        Case 17: MakeVal = "-1"
        Case 18: MakeVal = "abc"
        Case 19: MakeVal = ""
        Case 20: MakeVal = Null
        Case 21: MakeVal = Empty
        Case 22: MakeVal = CDate(1)
        Case 23: MakeVal = True
        Case 24: MakeVal = False
        Case 25: MakeVal = CDec(1)
        Case 26: MakeVal = CBool(-1)
        Case 27: MakeVal = "Yes"
        Case 28: MakeVal = CLng(-2)
        Case 29: MakeVal = CInt(3)
        Case 30: MakeVal = CLng(2147483647)
        Case 31: MakeVal = CInt(-32768)
        Case 32: MakeVal = CDbl(0)
        Case 33: MakeVal = CDbl(-1)
        Case 34: MakeVal = CDbl(2.5)
        Case 35: MakeVal = CSng(0)
        Case 36: MakeVal = CSng(-1)
        Case 37: MakeVal = CByte(0)
        Case 38: MakeVal = CByte(2)
        Case 39: MakeVal = CCur(0)
        Case 40: MakeVal = CCur(5)
        Case 41: MakeVal = CDate(0)
        Case 42: MakeVal = "TRUE"
        Case 43: MakeVal = "true"
        Case 44: MakeVal = " 1 "
        Case 45: MakeVal = "2"
        Case 46: MakeVal = "0.5"
        Case 47: MakeVal = "1.0"
        Case 48: MakeVal = "0.0"
        Case 49: MakeVal = "Off"
        Case 50: MakeVal = CDbl(1)
        Case 51: MakeVal = CDbl(0.0000001)
        Case 52: MakeVal = CDec(0)
        Case 53: MakeVal = CDec(2)
        Case 54: MakeVal = CLng(65536)
    End Select
End Function
Public Function ProbePrepare() As String
    On Error GoTo Failed
    Unload ToggleForm
    Load ToggleForm
    ToggleForm.Show vbModeless
    ProbePrepare = "ok"
    Exit Function
Failed:
    ProbePrepare = "ERR:" & CStr(Err.Number) & ":" & Err.Description
End Function
Public Function ProbeFinish() As String
    On Error GoTo Failed
    Unload ToggleForm
    ProbeFinish = "ok"
    Exit Function
Failed:
    ProbeFinish = "ERR:" & CStr(Err.Number) & ":" & Err.Description
End Function
Public Function ProbeProp(ByVal Name As String, ByVal Prop As String, ByVal Setting As Variant) As String
    On Error GoTo Failed
    Dim Ctl As Object
    Set Ctl = ToggleForm.Controls(Name)
    CallByName Ctl, Prop, VbLet, Setting
    ProbeProp = "ok"
    Exit Function
Failed:
    ProbeProp = "ERR:" & CStr(Err.Number) & ":" & Err.Description
End Function
Public Function ProbeReset(ByVal Name As String, ByVal Init As Long) As String
    On Error GoTo Failed
    Dim Ctl As Object
    Set Ctl = ToggleForm.Controls(Name)
    Select Case Init
        Case 0: Ctl.Value = False
        Case 1: Ctl.Value = True
        Case 2: Ctl.Value = Null
    End Select
    ToggleForm.Log = ""
    ProbeReset = "init=" & V(Ctl.Value)
    Exit Function
Failed:
    ToggleForm.Log = ""
    ProbeReset = "RESETERR:" & CStr(Err.Number) & ":" & Err.Description
End Function
Public Function ProbeSet(ByVal Name As String, ByVal Code As Long) As String
    On Error GoTo Failed
    Dim Ctl As Object, Err1 As Long, D1 As String, X As Variant
    Set Ctl = ToggleForm.Controls(Name)
    ToggleForm.Log = ""
    X = MakeVal(Code)
    On Error Resume Next
    Ctl.Value = X
    Err1 = Err.Number
    D1 = Err.Description
    Err.Clear
    On Error GoTo Failed
    ProbeSet = "err=" & CStr(Err1) & "|" & D1 & "|after=" & V(Ctl.Value) & "|log=" & ToggleForm.Log
    Exit Function
Failed:
    ProbeSet = "PROBEERR:" & CStr(Err.Number) & ":" & Err.Description
End Function
Public Function ProbeLiteral(ByVal Name As String, ByVal Kind As Long) As String
    On Error GoTo Failed
    Dim Ctl As Object, E As Long, D As String
    Set Ctl = ToggleForm.Controls(Name)
    ToggleForm.Log = ""
    On Error Resume Next
    Select Case Kind
        Case 0: Ctl.Value = -1
        Case 1: Ctl.Value = 1
        Case 2: Ctl.Value = 0
        Case 3: Ctl.Value = Null
    End Select
    E = Err.Number: D = Err.Description: Err.Clear
    On Error GoTo Failed
    ProbeLiteral = "err=" & CStr(E) & "|" & D & "|after=" & V(Ctl.Value) & "|log=" & ToggleForm.Log
    Exit Function
Failed:
    ProbeLiteral = "PROBEERR:" & CStr(Err.Number) & ":" & Err.Description
End Function
'''


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, required=True)
    parser.add_argument('--out', type=Path, required=True)
    parser.add_argument('--round', type=int, default=1)
    args = parser.parse_args()
    root = args.root.resolve()
    root.mkdir(parents=True, exist_ok=True)
    seed = root / 'seed.csv'
    seed.write_text('a\n', encoding='utf-8')
    pythoncom.CoInitialize()
    cmd = [str(EXCEL), '/x', '/automation', '/r', str(seed)]
    proc = subprocess.Popen(cmd, stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    pid = proc.pid
    print('excel launched pid', pid, flush=True)
    result = dict(schema='calcforms.toggle_coercion.v1', excel_pid=pid, excel_launches=1, cases=[])
    excel = None
    try:
        excel = wait_for(lambda: native_excel(pid), timeout=60)
        excel.Visible = False
        excel.DisplayAlerts = False
        result.update(excel_version=str(excel.Version), excel_build=str(excel.Build))
        book = excel.Workbooks.Add()
        form = book.VBProject.VBComponents.Add(3)
        form.Name = 'ToggleForm'
        form.CodeModule.AddFromString(FORM)
        mod = book.VBProject.VBComponents.Add(1)
        mod.Name = 'Probe'
        mod.CodeModule.AddFromString(MODULE)
        macro = lambda name, *a: excel.Run("'" + book.Name + "'!" + name, *a)
        print('prepare', macro('ProbePrepare'), flush=True)
        controls = ('T', 'C', 'O') if args.round == 1 else ('T',)
        codes = range(29) if args.round == 1 else range(29, 55)
        for ctl in controls:
            for triple in (False, True) if args.round == 1 else (False,):
                if ctl != 'O':
                    r = macro('ProbeProp', ctl, 'TripleState', triple)
                    result['cases'].append(dict(control=ctl, step='triplestate', value=triple, result=str(r)))
                elif triple:
                    continue
                for init in (0, 1) + ((2,) if triple else ()):
                    for code in codes:
                        reset = str(macro('ProbeReset', ctl, init))
                        row = str(macro('ProbeSet', ctl, code))
                        result['cases'].append(dict(control=ctl, triple=triple, init=init, code=code, reset=reset, result=row))
                    for kind in (range(4) if args.round == 1 else ()):
                        reset = str(macro('ProbeReset', ctl, init))
                        row = str(macro('ProbeLiteral', ctl, kind))
                        result['cases'].append(dict(control=ctl, triple=triple, init=init, literal=kind, reset=reset, result=row))
        print('finish', macro('ProbeFinish'), flush=True)
        book.Close(False)
    finally:
        args.out.write_text(json.dumps(result, indent=2) + '\n', encoding='utf-8')
        try:
            if excel is not None:
                excel.DisplayAlerts = False
                excel.Quit()
        except Exception as e:
            print('quit failed', e, flush=True)
        excel = None
        try:
            proc.wait(timeout=30)
        except subprocess.TimeoutExpired:
            proc.terminate()
            proc.wait(timeout=15)
        print('excel stopped rc', proc.returncode, flush=True)


if __name__ == '__main__':
    main()
