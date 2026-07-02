Option Explicit

' Host-neutral accessibility semantic snapshot. This is not a Windows UIA/MSAA provider; it is the
' value-shaped runtime data model that a provider can later adapt. Rows are deterministic so
' headless traces can prove focus, value, and selection transitions through OxRuntime.

Public Function Snapshot(ByVal Form As UserForm, ByVal FocusName As String) As String
    Dim Text As String
    Text = FormRow(Form, FocusName)

    Dim I As Long
    Dim Control As IOxControl
    For I = 1 To Form.Controls.Count
        Set Control = Form.Controls.Item(I)
        Text = Text & vbLf & ControlRow(Control, FocusName)
    Next I

    Snapshot = Text
End Function

Private Function FormRow(ByVal Form As UserForm, ByVal FocusName As String) As String
    FormRow = _
        "role=form" & _
        ";name=" & Encode(Form.Name) & _
        ";value=" & Encode(Form.Caption) & _
        ";enabled=True" & _
        ";visible=True" & _
        ";focused=" & BoolText(Len(FocusName) = 0) & _
        ";selected=False" & _
        ";sel_start=0" & _
        ";sel_length=0" & _
        ";sel_text=" & _
        ";patterns=container" & _
        ";row_count=0" & _
        ";column_count=0" & _
        ";control_count=" & CStr(Form.Controls.Count)
End Function

Private Function ControlRow(ByVal Control As IOxControl, ByVal FocusName As String) As String
    ControlRow = _
        "role=" & Encode(Control.AccessibilityRole) & _
        ";name=" & Encode(Control.AccessibilityName) & _
        ";value=" & Encode(Control.AccessibilityValue) & _
        ";enabled=" & BoolText(Control.Core.Enabled) & _
        ";visible=" & BoolText(Control.Core.Visible) & _
        ";focused=" & BoolText(Control.Core.Name = FocusName) & _
        ";selected=" & BoolText(Control.AccessibilitySelected) & _
        ";sel_start=" & CStr(Control.AccessibilitySelectionStart) & _
        ";sel_length=" & CStr(Control.AccessibilitySelectionLength) & _
        ";sel_text=" & Encode(Control.AccessibilitySelectionText) & _
        ";patterns=" & Encode(Control.AccessibilityPatterns) & _
        ";row_count=0" & _
        ";column_count=0" & _
        ";focusable=" & BoolText(Control.Core.Focusable) & _
        ";tabstop=" & BoolText(Control.Core.TabStop)
End Function

Private Function BoolText(ByVal Value As Boolean) As String
    If Value Then
        BoolText = "True"
    Else
        BoolText = "False"
    End If
End Function

Private Function Encode(ByVal Value As String) As String
    Dim Out As String
    Dim I As Long
    Dim Ch As String

    For I = 1 To Len(Value)
        Ch = Mid$(Value, I, 1)
        If Ch = "\" Then
            Out = Out & "\\"
        ElseIf Ch = ";" Then
            Out = Out & "\;"
        ElseIf Ch = "=" Then
            Out = Out & "\="
        ElseIf Ch = vbLf Then
            Out = Out & "\n"
        ElseIf Ch = vbCr Then
            Out = Out & "\r"
        Else
            Out = Out & Ch
        End If
    Next I

    Encode = Out
End Function
