Option Explicit

' W002 smoke-only PAL diagnostic fixture.
' This is not an MSForms compatibility API and does not model UserForm behavior.

Public Sub Main()
    EmitSmokeCanvas 4, 3
    EmitSmokeFillRect 1, 1, 2, 1, 16, 32, 48, 255
    EmitSmokeFlush
End Sub

Private Sub EmitSmokeCanvas(ByVal width As Long, ByVal height As Long)
    Debug.Print "OXFORMS_SMOKE_CANVAS|width=" & CStr(width) & "|height=" & CStr(height)
End Sub

Private Sub EmitSmokeFillRect( _
    ByVal x As Long, _
    ByVal y As Long, _
    ByVal width As Long, _
    ByVal height As Long, _
    ByVal red As Long, _
    ByVal green As Long, _
    ByVal blue As Long, _
    ByVal alpha As Long)

    Debug.Print "OXFORMS_SMOKE_FILLRECT" & _
        "|x=" & CStr(x) & _
        "|y=" & CStr(y) & _
        "|width=" & CStr(width) & _
        "|height=" & CStr(height) & _
        "|red=" & CStr(red) & _
        "|green=" & CStr(green) & _
        "|blue=" & CStr(blue) & _
        "|alpha=" & CStr(alpha)
End Sub

Private Sub EmitSmokeFlush()
    Debug.Print "OXFORMS_SMOKE_FLUSH"
End Sub
