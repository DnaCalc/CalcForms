Option Explicit

' oxforms-98v spike: exercise the CalcForms.Surface.MeasureBatch typed-record round-trip
' directly, end to end through the real CalcVBA dispatch. Test infrastructure, not the CalcForms
' library. Build an OxMeasureRequest() array (UDT SAFEARRAY in), call MeasureBatch once, and
' read back an OxMeasureResult() array (UDT SAFEARRAY out) — proving captions cross as native
' String fields and metrics as typed Longs, with no string packing on either side.

Private mSurface As Object

Private Sub Class_Initialize()
    Set mSurface = Nothing
End Sub

Public Sub Build()
    Set mSurface = CreateObject("CalcForms.Surface")
End Sub

' Measure two captions in ONE crossing. Return a test-parseable
' "runId,advanceMilliPt,heightMilliPt;runId,advanceMilliPt,heightMilliPt" so the Rust test
' can assert each row's typed fields round-tripped (the run id is a content hash of the exact
' caption, so a matching id proves the caption crossed verbatim).
Public Function ProbeTwo() As String
    Dim reqs(0 To 1) As OxMeasureRequest
    reqs(0).FontId = 1
    reqs(0).SizeMilliPt = 12000
    reqs(0).Caption = "Hello"
    reqs(1).FontId = 1
    reqs(1).SizeMilliPt = 12000
    reqs(1).Caption = "Hi"

    Dim res() As OxMeasureResult
    res = mSurface.MeasureBatch((reqs))

    ProbeTwo = _
        res(0).RunId & "," & CStr(res(0).AdvanceMilliPt) & "," & _
        CStr(res(0).AscentMilliPt + res(0).DescentMilliPt) & ";" & _
        res(1).RunId & "," & CStr(res(1).AdvanceMilliPt) & "," & _
        CStr(res(1).AscentMilliPt + res(1).DescentMilliPt)
End Function
