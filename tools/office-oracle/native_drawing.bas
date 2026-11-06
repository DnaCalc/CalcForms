Option Explicit

' Black-box observation through the public OLE drawing API. No window input.
Private Type DrawingRect
    Left As Long
    Top As Long
    Right As Long
    Bottom As Long
End Type
Private Declare PtrSafe Function CreateEnhMetaFileW Lib "gdi32" (ByVal Ref As LongPtr, ByVal File As LongPtr, ByRef Frame As DrawingRect, ByVal Description As LongPtr) As LongPtr
Private Declare PtrSafe Function CloseEnhMetaFile Lib "gdi32" (ByVal DC As LongPtr) As LongPtr
Private Declare PtrSafe Function DeleteEnhMetaFile Lib "gdi32" (ByVal Metafile As LongPtr) As Long
Private Declare PtrSafe Function OleDraw Lib "ole32" (ByVal Object As LongPtr, ByVal Aspect As Long, ByVal DC As LongPtr, ByRef Bounds As DrawingRect) As Long

Public Function LayoutDraw(ByVal File As String, ByVal WidthPx As Long, ByVal HeightPx As Long) As String
    On Error GoTo Failed
    Dim Form As Object
    Set Form = LayoutCaptureForm()
    LayoutDraw = DrawObject(Form, File, WidthPx, HeightPx)
    Exit Function
Failed:
    LayoutDraw = "CALCFORMS_NATIVE_ERROR:" & CStr(Err.Number) & ":" & Err.Description
End Function

Public Function LayoutDrawControl(ByVal ControlPath As String, ByVal File As String, ByVal WidthPx As Long, ByVal HeightPx As Long) As String
    On Error GoTo Failed
    Dim Control As Object, Part As Variant
    Set Control = LayoutCaptureForm()
    For Each Part In Split(ControlPath, ".")
        Set Control = Control.Controls.Item(CStr(Part))
    Next
    LayoutDrawControl = DrawObject(Control, File, WidthPx, HeightPx)
    Exit Function
Failed:
    LayoutDrawControl = "CALCFORMS_NATIVE_ERROR:" & CStr(Err.Number) & ":" & Err.Description
End Function

Private Function DrawObject(ByVal Form As Object, ByVal File As String, ByVal WidthPx As Long, ByVal HeightPx As Long) As String
    On Error GoTo Failed
    Dim DC As LongPtr, Metafile As LongPtr
    Dim Bounds As DrawingRect, Frame As DrawingRect, Result As Long
    If Form Is Nothing Then Err.Raise 91, "LayoutDraw", "No shown capture form"
    If WidthPx <= 0 Or HeightPx <= 0 Then Err.Raise 5, "LayoutDraw", "Invalid client size"
    Bounds.Right = WidthPx: Bounds.Bottom = HeightPx
    ' The oracle desktop is 96 DPI. The frame is in 0.01 millimetres.
    Frame.Right = CLng(WidthPx * 2540# / 96#)
    Frame.Bottom = CLng(HeightPx * 2540# / 96#)
    DC = CreateEnhMetaFileW(0, StrPtr(File), Frame, 0)
    If DC = 0 Then Err.Raise 5, "LayoutDraw", "CreateEnhMetaFile failed"
    Result = OleDraw(ObjPtr(Form), 1, DC, Bounds)
    Metafile = CloseEnhMetaFile(DC): DC = 0
    If Metafile = 0 Then Err.Raise 5, "LayoutDraw", "CloseEnhMetaFile failed"
    DeleteEnhMetaFile Metafile: Metafile = 0
    If Result <> 0 Then Err.Raise 5, "LayoutDraw", "OleDraw HRESULT " & CStr(Result)
    DrawObject = "ok"
    Exit Function
Failed:
    DrawObject = "CALCFORMS_NATIVE_ERROR:" & CStr(Err.Number) & ":" & Err.Description
    On Error Resume Next
    If DC <> 0 Then Metafile = CloseEnhMetaFile(DC)
    If Metafile <> 0 Then DeleteEnhMetaFile Metafile
End Function
