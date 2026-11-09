"""Round 12 native probes in one owned hidden Excel (macro calls only).

.131  Designer and Controls.Add TabIndex assignment across Frame/Image/Spin/Scroll/TabStrip/MultiPage.
.124  Events from programmatic Text, first Show and redundant SetFocus.
.118  ListBox Height after IntegralHeight, Show and font/border/zoom variations.
"""
import argparse
import json
from pathlib import Path

from hidden_excel import hidden_excel

TAB_FORM_RUNTIME = '''Option Explicit
Private Sub UserForm_Initialize()
    Dim C As Object
    Set C = Me.Controls.Add("Forms.Frame.1", "Group")
    C.Left = 12: C.Top = 12: C.Width = 174: C.Height = 72
    Set C = Me.Controls.Add("Forms.Image.1", "Picture")
    C.Left = 210: C.Top = 12: C.Width = 66: C.Height = 54
    Set C = Me.Controls.Add("Forms.SpinButton.1", "Spinner")
    C.Left = 300: C.Top = 12: C.Width = 18: C.Height = 54
    Set C = Me.Controls.Add("Forms.ScrollBar.1", "Slider")
    C.Left = 12: C.Top = 102: C.Width = 174: C.Height = 18
    Set C = Me.Controls.Add("Forms.TabStrip.1", "TabsControl")
    C.Left = 12: C.Top = 144: C.Width = 174: C.Height = 102
    Set C = Me.Controls.Add("Forms.MultiPage.1", "PagesControl")
    C.Left = 210: C.Top = 102: C.Width = 162: C.Height = 144
    Set C = Me.Controls("Group").Controls.Add("Forms.Label.1", "NestedLabel")
    Set C = Me.Controls("Group").Controls.Add("Forms.TextBox.1", "NestedInput")
End Sub
'''

INPUT_FORM = '''Option Explicit
Public Log As String
Public WithEvents Qty As MSForms.TextBox
Public WithEvents Other As MSForms.TextBox
Private Sub UserForm_Initialize()
    Set Qty = Me.Controls.Add("Forms.TextBox.1", "Qty")
    Set Other = Me.Controls.Add("Forms.TextBox.1", "Other")
    Qty.Left = 6: Qty.Top = 6: Qty.Width = 90: Qty.Height = 18
    Other.Left = 6: Other.Top = 40: Other.Width = 90: Other.Height = 18
End Sub
Private Sub Qty_Change(): Log = Log & "Qty.Change(" & Qty.Text & ");": End Sub
Private Sub Qty_Enter(): Log = Log & "Qty.Enter;": End Sub
Private Sub Qty_Exit(ByVal Cancel As MSForms.ReturnBoolean): Log = Log & "Qty.Exit;": End Sub
Private Sub Qty_BeforeUpdate(ByVal Cancel As MSForms.ReturnBoolean): Log = Log & "Qty.BeforeUpdate;": End Sub
Private Sub Qty_AfterUpdate(): Log = Log & "Qty.AfterUpdate;": End Sub
Private Sub Other_Change(): Log = Log & "Other.Change(" & Other.Text & ");": End Sub
Private Sub Other_Enter(): Log = Log & "Other.Enter;": End Sub
Private Sub Other_Exit(ByVal Cancel As MSForms.ReturnBoolean): Log = Log & "Other.Exit;": End Sub
Private Sub Other_BeforeUpdate(ByVal Cancel As MSForms.ReturnBoolean): Log = Log & "Other.BeforeUpdate;": End Sub
Private Sub Other_AfterUpdate(): Log = Log & "Other.AfterUpdate;": End Sub
Private Sub UserForm_Activate(): Log = Log & "Form.Activate;": End Sub
Private Sub UserForm_Deactivate(): Log = Log & "Form.Deactivate;": End Sub
'''

LIST_FORM = '''Option Explicit
Private Sub UserForm_Initialize()
    Dim L As Object, I As Long
    Set L = Me.Controls.Add("Forms.ListBox.1", "L")
    L.Left = 6: L.Top = 6: L.Width = 120: L.Height = 72
    For I = 0 To 29
        L.AddItem "Row " & CStr(I)
    Next I
End Sub
'''

MODULE = '''Option Explicit
Private Function TI(ByVal C As Object) As String
    Dim V As Variant
    On Error Resume Next
    V = C.TabIndex
    If Err.Number <> 0 Then
        TI = "err" & CStr(Err.Number)
        Err.Clear
    Else
        TI = CStr(V)
    End If
End Function
Private Function Walk(ByVal Controls As Object) As String
    Dim C As Object, S As String
    For Each C In Controls
        S = S & C.Name & ":" & TypeName(C) & ":" & TI(C) & ";"
    Next C
    Walk = S
End Function
Public Function TabsRuntime() As String
    On Error GoTo Failed
    Unload RunTabForm
    Load RunTabForm
    TabsRuntime = "form=" & Walk(RunTabForm.Controls) & "|group=" & Walk(RunTabForm.Controls("Group").Controls)
    Unload RunTabForm
    Exit Function
Failed:
    TabsRuntime = "ERR:" & CStr(Err.Number) & ":" & Err.Description
End Function
Public Function TabsDesign() As String
    On Error GoTo Failed
    Unload DesTabForm
    Load DesTabForm
    TabsDesign = "form=" & Walk(DesTabForm.Controls)
    Unload DesTabForm
    Exit Function
Failed:
    TabsDesign = "ERR:" & CStr(Err.Number) & ":" & Err.Description
End Function
Public Function InputRun(ByVal Scenario As Long) As String
    On Error GoTo Failed
    Dim S As String
    Unload InputForm
    Load InputForm
    InputForm.Log = ""
    Select Case Scenario
        Case 0
            InputForm.Qty.Text = "5"
            S = S & "[settext]" & InputForm.Log: InputForm.Log = ""
            InputForm.Show vbModeless
            S = S & "[show]" & InputForm.Log: InputForm.Log = ""
            InputForm.Qty.SetFocus
            S = S & "[setfocus-qty]" & InputForm.Log: InputForm.Log = ""
            InputForm.Qty.SetFocus
            S = S & "[setfocus-qty-again]" & InputForm.Log: InputForm.Log = ""
            InputForm.Other.SetFocus
            S = S & "[setfocus-other]" & InputForm.Log: InputForm.Log = ""
        Case 1
            InputForm.Show vbModeless
            S = S & "[show]" & InputForm.Log: InputForm.Log = ""
            InputForm.Qty.SetFocus
            S = S & "[setfocus-qty]" & InputForm.Log: InputForm.Log = ""
            InputForm.Qty.Text = "6"
            S = S & "[settext-focused]" & InputForm.Log: InputForm.Log = ""
            InputForm.Qty.SetFocus
            S = S & "[setfocus-qty-again]" & InputForm.Log: InputForm.Log = ""
            InputForm.Other.SetFocus
            S = S & "[setfocus-other]" & InputForm.Log: InputForm.Log = ""
            InputForm.Qty.SetFocus
            S = S & "[back-to-qty]" & InputForm.Log: InputForm.Log = ""
            InputForm.Other.SetFocus
            S = S & "[other-again]" & InputForm.Log: InputForm.Log = ""
        Case 2
            InputForm.Show vbModeless
            S = S & "[show]" & InputForm.Log: InputForm.Log = ""
            InputForm.Qty.Text = "7"
            S = S & "[settext-unfocused]" & InputForm.Log: InputForm.Log = ""
            InputForm.Qty.SetFocus
            S = S & "[setfocus-qty]" & InputForm.Log: InputForm.Log = ""
            InputForm.Other.SetFocus
            S = S & "[setfocus-other]" & InputForm.Log: InputForm.Log = ""
        Case 3
            InputForm.Show vbModeless
            InputForm.Log = ""
            InputForm.Other.Text = "x"
            InputForm.Other.SetFocus
            InputForm.Log = ""
            InputForm.Qty.Text = "8"
            InputForm.Qty.Text = "8"
            S = S & "[settext-twice]" & InputForm.Log: InputForm.Log = ""
            InputForm.Qty.SetFocus
            S = S & "[to-qty]" & InputForm.Log: InputForm.Log = ""
            InputForm.Hide
            S = S & "[hide]" & InputForm.Log: InputForm.Log = ""
            InputForm.Show vbModeless
            S = S & "[reshow]" & InputForm.Log: InputForm.Log = ""
        Case 4
            InputForm.Qty.SetFocus
            S = S & "[setfocus-before-show]" & InputForm.Log: InputForm.Log = ""
    End Select
    InputRun = S
    Unload InputForm
    Exit Function
Failed:
    InputRun = S & "ERR:" & CStr(Err.Number) & ":" & Err.Description
End Function
Public Function ListRun(ByVal Zoom As Long, ByVal FontName As String, ByVal FontSize As Single, ByVal Border As Long, ByVal IH As Boolean, ByVal H As Single) As String
    On Error GoTo Failed
    Dim L As Object, S As String
    Unload ListForm
    Load ListForm
    ListForm.Zoom = Zoom
    Set L = ListForm.Controls("L")
    L.Font.Name = FontName
    L.Font.Size = FontSize
    L.BorderStyle = Border
    L.IntegralHeight = IH
    S = "init=" & CStr(L.Height)
    L.Height = H
    S = S & ";set=" & CStr(L.Height)
    ListForm.Show vbModeless
    S = S & ";shown=" & CStr(L.Height)
    L.Height = H
    S = S & ";reset=" & CStr(L.Height)
    L.ListIndex = 29
    S = S & ";top=" & CStr(L.TopIndex)
    L.ListIndex = 0
    S = S & ";top0=" & CStr(L.TopIndex)
    ListForm.Hide
    ListRun = S
    Unload ListForm
    Exit Function
Failed:
    ListRun = S & "ERR:" & CStr(Err.Number) & ":" & Err.Description
End Function
'''


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, required=True)
    parser.add_argument('--out', type=Path, required=True)
    parser.add_argument('--skip-list', action='store_true')
    args = parser.parse_args()
    result = dict(schema='calcforms.round12_native.v1', excel_launches=1, tabs={}, input={}, list=[])
    try:
        with hidden_excel(args.root) as (excel, pid):
            result.update(excel_pid=pid, excel_version=str(excel.Version), excel_build=str(excel.Build))
            book = excel.Workbooks.Add()
            project = book.VBProject
            for name, code in (('RunTabForm', TAB_FORM_RUNTIME), ('InputForm', INPUT_FORM), ('ListForm', LIST_FORM)):
                form = project.VBComponents.Add(3)
                form.Name = name
                form.CodeModule.AddFromString(code)
            design = project.VBComponents.Add(3)
            design.Name = 'DesTabForm'
            designer = design.Designer
            for name, kind, x, y, w, h in [('Group', 'Frame', 12, 12, 174, 72), ('Picture', 'Image', 210, 12, 66, 54),
                                          ('Spinner', 'SpinButton', 300, 12, 18, 54), ('Slider', 'ScrollBar', 12, 102, 174, 18),
                                          ('TabsControl', 'TabStrip', 12, 144, 174, 102), ('PagesControl', 'MultiPage', 210, 102, 162, 144)]:
                control = designer.Controls.Add('Forms.' + kind + '.1', name, True)
                control.Left, control.Top, control.Width, control.Height = x, y, w, h
            for name, kind in (('NestedLabel', 'Label'), ('NestedInput', 'TextBox')):
                try:
                    designer.Controls.Item('Group').Controls.Add('Forms.' + kind + '.1', name, True)
                except Exception as error:
                    result['tabs'].setdefault('design_nested_error', []).append(str(error))
            mod = project.VBComponents.Add(1)
            mod.Name = 'Probe'
            mod.CodeModule.AddFromString(MODULE)
            macro = lambda name, *a: excel.Run("'" + book.Name + "'!" + name, *a)
            result['tabs']['runtime'] = str(macro('TabsRuntime'))
            result['tabs']['design'] = str(macro('TabsDesign'))
            print(result['tabs'], flush=True)
            for scenario in range(5):
                result['input'][str(scenario)] = str(macro('InputRun', scenario))
                print(scenario, result['input'][str(scenario)], flush=True)
            if not args.skip_list:
                heights = [30, 40, 45, 50, 55, 60, 65, 70, 71, 72, 73, 75, 80, 85, 90, 95, 100, 110, 120]
                for zoom in (100, 150):
                    for font, size in (('Tahoma', 8.25), ('Tahoma', 10), ('Arial', 12)):
                        for border in (1, 0):
                            for ih in (True, False):
                                for h in heights:
                                    row = str(macro('ListRun', zoom, font, size, border, ih, float(h)))
                                    result['list'].append(dict(zoom=zoom, font=font, size=size, border=border, integral=ih, height=h, result=row))
                print(len(result['list']), 'list rows', flush=True)
            book.Close(False)
    finally:
        args.out.write_text(json.dumps(result, indent=2) + '\n', encoding='utf-8')


if __name__ == '__main__':
    main()
