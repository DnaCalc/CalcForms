Option Explicit

' oxforms-lex perf probe (test infrastructure, not the OxForms library). Scaling of
' VBA-side hit-testing on OxVba vm3, to inform whether hit-testing should be offloaded to
' the Rust kernel (the deferred OxForms.Surface HitTest crossing). Holds N control rects in
' a grid and runs a linear hit-test over them in VBA -- the SAME algorithm the Rust kernel
' runs natively -- so the harness can compare per-op cost. Noop isolates the bare VBA
' invoke/marshal crossing overhead (the per-input "message-loop tax") from the hit-test
' compute. No rendering here: this measures the geometric search only.

Private mN As Long
Private mX() As Long
Private mY() As Long
Private mW() As Long
Private mH() As Long

' Build N control rects as a grid of fixed-size cells (cols wide).
Public Sub Setup(ByVal N As Long)
    mN = N
    ReDim mX(0 To N - 1)
    ReDim mY(0 To N - 1)
    ReDim mW(0 To N - 1)
    ReDim mH(0 To N - 1)
    Dim i As Long
    Dim cols As Long, cw As Long, ch As Long
    cols = 40
    cw = 24
    ch = 16
    For i = 0 To N - 1
        mX(i) = (i Mod cols) * cw
        mY(i) = (i \ cols) * ch
        mW(i) = cw - 2
        mH(i) = ch - 2
    Next i
End Sub

' Linear hit-test over all N rects, last (top-most z-order) wins. Returns the hit index or
' -1. This is the per-input geometric search a VBA-side reducer would run on each event.
Public Function HitTestAll(ByVal X As Long, ByVal Y As Long) As Long
    Dim i As Long
    Dim hit As Long
    hit = -1
    For i = 0 To mN - 1
        If (X >= mX(i)) And (X < mX(i) + mW(i)) And _
           (Y >= mY(i)) And (Y < mY(i) + mH(i)) Then
            hit = i
        End If
    Next i
    HitTestAll = hit
End Function

' A trivial crossing to isolate the bare VBA invoke/marshal overhead from the hit-test cost.
Public Function Noop() As Long
    Noop = 0
End Function

' Isolation pair (pinpoints WHICH op is O(N)). Both loop Reps times with identical structure;
' the ONLY difference is that ScanArray reads one array element per iteration (indices sweep the
' whole array via Mod mN) while ScanPlain does pure arithmetic. With Reps fixed and the array
' LENGTH (mN) varied via Setup, a per-read cost (ScanArray - ScanPlain)/Reps that GROWS with mN
' proves dynamic-array element access is O(N), not O(1).
Public Function ScanArray(ByVal Reps As Long) As Long
    Dim i As Long
    Dim s As Long
    s = 0
    For i = 0 To Reps - 1
        s = s + mX(i Mod mN)
    Next i
    ScanArray = s
End Function

Public Function ScanPlain(ByVal Reps As Long) As Long
    Dim i As Long
    Dim s As Long
    s = 0
    For i = 0 To Reps - 1
        s = s + (i Mod 7)
    Next i
    ScanPlain = s
End Function
