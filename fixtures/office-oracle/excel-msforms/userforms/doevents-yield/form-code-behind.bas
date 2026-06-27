Option Explicit

' W006 DoEvents-yield oracle UserForm code-behind.
'
' YieldButton fills the form, so a single click at the window centre always lands
' on it. The first Click (handler depth 1) logs its DoEvents call site and then
' pumps DoEvents in a bounded loop. While that loop is pumping, the capture
' injects a SECOND click at the same point: MSForms dispatches it through the
' DoEvents pump, REENTERING YieldButton_Click at depth 2. The reentrant
' invocation logs and returns immediately (it does not pump again), so the
' reentrant rows are sandwiched between the outer BeforeDoEvents and AfterDoEvents
' rows -- a deterministic record of reentrant event dispatch during a DoEvents
' yield, with nesting depth. No OxForms runtime DoEvents behaviour is implied.

Private Sub UserForm_Initialize()
    W006DoEventsLog Me.Name, "UserForm", "Initialize", "lifecycle", "form initialize"
End Sub

Private Sub YieldButton_Click()
    W006DoEventsEnterHandler "YieldButton_Click"

    Dim depth As Long
    depth = W006DoEventsHandlerDepth()
    W006DoEventsLog Me.Name, "YieldButton", "Click", "handler", "click handler start at depth " & CStr(depth)

    If depth = 1 Then
        W006DoEventsLog Me.Name, "YieldButton", "BeforeDoEvents", "handler", "DoEvents call site; entering bounded pump loop"
        Dim startSeconds As Double
        startSeconds = Timer
        Do While (Timer - startSeconds) < 3.5
            DoEvents
        Loop
        W006DoEventsLog Me.Name, "YieldButton", "AfterDoEvents", "handler", "DoEvents pump loop returned"
    Else
        W006DoEventsLog Me.Name, "YieldButton", "ReentrantClick", "reentrant_handler", "this Click reentered YieldButton_Click during the outer DoEvents pump at depth " & CStr(depth)
    End If

    W006DoEventsLog Me.Name, "YieldButton", "ClickEnd", "handler", "click handler resume/end at depth " & CStr(depth)
    W006DoEventsExitHandler
End Sub
