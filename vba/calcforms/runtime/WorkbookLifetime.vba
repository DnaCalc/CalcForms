Option Explicit
' Office language-facing form operations. Lifecycle state belongs to each form.
Public Const vbModeless As Long = 0
Public Const vbModal As Long = 1

Public Sub Load(ByVal Form As Object)
    Dim Lifecycle As ICalcFormsLifecycle
    Set Lifecycle = Form
    Lifecycle.LoadForm
End Sub

Public Sub Unload(ByVal Form As Object)
    Dim Lifecycle As ICalcFormsLifecycle
    Set Lifecycle = Form
    Lifecycle.UnloadForm 1
End Sub
