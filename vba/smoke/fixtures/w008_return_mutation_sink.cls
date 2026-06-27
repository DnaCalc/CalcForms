Option Explicit

' W008 ByRef Return* helper-mutation sink (oxforms-esq.1). Ordinary VBA WithEvents
' sink whose handlers mutate the passed-in Return* helper's .Value, exercising the
' readback path the runtime needs: KeyDown swallows the key (KeyCode -> 0) and
' QueryClose vetoes the close (Cancel -> -1), both via the shared helper object.

Private WithEvents Source As W008ReturnMutationSource

Public Sub Attach(ByVal Src As W008ReturnMutationSource)
    Set Source = Src
End Sub

Private Sub Source_KeyDownLike(ByVal KeyCode As W008ReturnValue, ByVal Shift As Integer)
    KeyCode.Value = 0
End Sub

Private Sub Source_QueryCloseLike(ByVal Cancel As W008ReturnValue)
    Cancel.Value = -1
End Sub
