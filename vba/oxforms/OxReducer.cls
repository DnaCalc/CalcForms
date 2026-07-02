Option Explicit

' Compatibility facade for the VBA reducer entrypoints that OxRuntime and form fixtures already
' call. The interaction state and routing policy live in OxInteractionManager; this class stays
' as the stable public reducer handle while W009 turns the interaction manager into a first-class
' subsystem.

Private mInteraction As OxInteractionManager

Public Sub Init(ByVal Form As UserForm)
    Set mInteraction = New OxInteractionManager
    mInteraction.Init Form
End Sub

Public Sub SetClipboardText(ByVal Text As String)
    mInteraction.SetClipboardText Text
End Sub

Public Property Get ClipboardText() As String
    ClipboardText = mInteraction.ClipboardText
End Property

Public Property Get FocusName() As String
    FocusName = mInteraction.FocusName
End Property

Public Property Get CaptureName() As String
    CaptureName = mInteraction.CaptureName
End Property

Public Property Get PressedName() As String
    PressedName = mInteraction.PressedName
End Property

Public Property Get HoverName() As String
    HoverName = mInteraction.HoverName
End Property

Public Property Get CursorTargetName() As String
    CursorTargetName = mInteraction.CursorTargetName
End Property

Public Property Get CursorPointer() As Long
    CursorPointer = mInteraction.CursorPointer
End Property

Public Property Get InteractionStateSummary() As String
    InteractionStateSummary = mInteraction.InteractionStateSummary
End Property

Public Property Get InteractionIndexBuildCount() As Long
    InteractionIndexBuildCount = mInteraction.InteractionIndexBuildCount
End Property

Public Sub InvalidateInteractionIndex()
    mInteraction.InvalidateInteractionIndex
End Sub

Public Property Get InteractionIndexSummary() As String
    InteractionIndexSummary = mInteraction.InteractionIndexSummary
End Property

Public Function Dispatch( _
        ByVal Kind As String, ByVal X As Long, ByVal Y As Long, _
        ByVal Button As Integer, ByVal Shift As Integer) As String
    Dispatch = mInteraction.Dispatch(Kind, X, Y, Button, Shift)
End Function

Public Function DispatchKey(ByVal Kind As String, ByVal KeyCode As Integer, ByVal Shift As Integer) As String
    DispatchKey = mInteraction.DispatchKey(Kind, KeyCode, Shift)
End Function

Public Function DispatchDrop(ByVal Text As String) As String
    DispatchDrop = mInteraction.DispatchDrop(Text)
End Function

Public Function DispatchChar(ByVal Text As String) As String
    DispatchChar = mInteraction.DispatchChar(Text)
End Function
