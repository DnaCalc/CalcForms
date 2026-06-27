Option Explicit

' Shared worksheet logger + active-handler depth tracker + show/clear macros for
' the W006 DoEvents-yield oracle. The depth tracker is the load-bearing piece:
' YieldButton_Click increments it on entry and decrements on exit, so a row's
' handler_depth records how many click handlers are simultaneously on the VBA
' call stack. A depth of 2 means a Click was dispatched (through the DoEvents
' pump) while an earlier Click handler had not yet returned.

Private gW006DoEventsSeq As Long
Private gW006DoEventsHandlerDepth As Long
Private gW006DoEventsActiveHandler As String

Public Sub W006DoEventsEnterHandler(ByVal handlerName As String)
    gW006DoEventsHandlerDepth = gW006DoEventsHandlerDepth + 1
    gW006DoEventsActiveHandler = handlerName
End Sub

Public Sub W006DoEventsExitHandler()
    If gW006DoEventsHandlerDepth > 0 Then
        gW006DoEventsHandlerDepth = gW006DoEventsHandlerDepth - 1
    End If
    If gW006DoEventsHandlerDepth = 0 Then
        gW006DoEventsActiveHandler = ""
    End If
End Sub

Public Function W006DoEventsHandlerDepth() As Long
    W006DoEventsHandlerDepth = gW006DoEventsHandlerDepth
End Function

Public Sub W006DoEventsLog( _
        ByVal formName As String, _
        ByVal controlName As String, _
        ByVal eventName As String, _
        ByVal rowKind As String, _
        ByVal notes As String)
    Dim ws As Worksheet
    Set ws = W006DoEventsSheet()
    gW006DoEventsSeq = gW006DoEventsSeq + 1
    Dim r As Long
    r = gW006DoEventsSeq + 1
    ws.Cells(r, 1).Value = gW006DoEventsSeq
    ws.Cells(r, 2).Value = formName
    ws.Cells(r, 3).Value = controlName
    ws.Cells(r, 4).Value = eventName
    ws.Cells(r, 5).Value = rowKind
    ws.Cells(r, 6).Value = gW006DoEventsHandlerDepth
    ws.Cells(r, 7).Value = gW006DoEventsActiveHandler
    ws.Cells(r, 8).Value = notes
End Sub

Public Sub W006DoEventsDeferred()
    ' Reserved hook: an Application.OnTime path could also exercise the pump.
    ' The capture drives reentrancy with a second click instead, which is
    ' deterministic, so this is intentionally a no-op marker only.
    W006DoEventsLog "OxFormsW006DoEvents", "(deferred)", "DeferredMarker", "diagnostic", "reserved Application.OnTime hook; not used by the deterministic dual-click capture"
End Sub

Private Function W006DoEventsSheet() As Worksheet
    Dim ws As Worksheet
    On Error Resume Next
    Set ws = ThisWorkbook.Worksheets("W006DoEventsLog")
    On Error GoTo 0
    If ws Is Nothing Then
        Set ws = ThisWorkbook.Worksheets.Add
        ws.Name = "W006DoEventsLog"
    End If
    If Len(CStr(ws.Cells(1, 1).Value)) = 0 Then
        ws.Cells(1, 1).Value = "sequence"
        ws.Cells(1, 2).Value = "form_name"
        ws.Cells(1, 3).Value = "control_name"
        ws.Cells(1, 4).Value = "event_name"
        ws.Cells(1, 5).Value = "row_kind"
        ws.Cells(1, 6).Value = "handler_depth"
        ws.Cells(1, 7).Value = "active_handler"
        ws.Cells(1, 8).Value = "notes"
    End If
    Set W006DoEventsSheet = ws
End Function

Public Sub ClearW006DoEventsLog()
    gW006DoEventsSeq = 0
    gW006DoEventsHandlerDepth = 0
    gW006DoEventsActiveHandler = ""
    Dim ws As Worksheet
    On Error Resume Next
    Set ws = ThisWorkbook.Worksheets("W006DoEventsLog")
    On Error GoTo 0
    If Not ws Is Nothing Then
        ws.Cells.Clear
    End If
End Sub

Public Sub ShowW006DoEventsModeless()
    OxFormsW006DoEvents.Show vbModeless
End Sub
