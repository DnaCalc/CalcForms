Option Explicit
Public Function Run8StaticIntegral() As String
    On Error GoTo Failed
    Load LayoutSelection
    LayoutSelection.Show vbModeless
    Dim C As MSForms.ListBox, S As String, I As Long
    Set C = LayoutSelection.Controls("Choices")
    S = "default=" & CStr(C.IntegralHeight) & ";font=" & CStr(C.Font.Size)
    C.Clear
    C.Height = 72
    For I = 0 To 22
        C.AddItem "Row " & CStr(I)
    Next I
    C.ListIndex = 22
    C.TopIndex = 99
    S = S & ";default_top=" & CStr(C.TopIndex)
    C.IntegralHeight = True
    C.ListIndex = 0
    C.TopIndex = 0
    C.ListIndex = 22
    C.TopIndex = 99
    S = S & ";true_top=" & CStr(C.TopIndex) & ";true_height=" & CStr(C.Height)
    C.IntegralHeight = False
    C.ListIndex = 0
    C.TopIndex = 0
    C.ListIndex = 22
    C.TopIndex = 99
    S = S & ";false_top=" & CStr(C.TopIndex) & ";false_height=" & CStr(C.Height)
    LayoutSelection.Hide
    Run8StaticIntegral = S
    Exit Function
Failed:
    Run8StaticIntegral = "CALCFORMS_NATIVE_ERROR:" & CStr(Err.Number) & ":" & Err.Description
End Function
