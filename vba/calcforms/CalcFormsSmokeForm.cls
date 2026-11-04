VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "CalcFormsSmokeForm"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = False
Attribute VB_PredeclaredId = False
Attribute VB_Exposed = True
Option Explicit

' W002 smoke-only form-like object.
' It uses the injected PAL canvas internally and does not model UserForm.Show.

Private mCanvas As Object

Private Sub Class_Initialize()
    Set mCanvas = Nothing
    Set mCanvas = CreateObject("CalcForms.SmokeCanvas")
End Sub

Public Function RenderRectangleSmoke() As Long
    mCanvas.CreateSurface 4, 3
    mCanvas.FillRect 1, 1, 2, 1, 16, 32, 48, 255
    RenderRectangleSmoke = mCanvas.Flush()
End Function
