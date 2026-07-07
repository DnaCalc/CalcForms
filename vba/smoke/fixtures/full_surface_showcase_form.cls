Option Explicit

' Living OxForms full-surface showcase. This is a runnable form-document, not an oracle:
' it renders every control currently implemented by OxForms, lists future intrinsic controls
' as pending rows, and exposes a deterministic RunSelfTest method that drives the current
' reducer/event surface end to end. Future control lanes should extend this file rather than
' creating one-off demos.

Private mForm As UserForm
Private mReducer As OxReducer
Private WithEvents mTitle As Label
Private WithEvents mInput As TextBox
Private WithEvents mOk As CommandButton
Private WithEvents mCancel As CommandButton
Private WithEvents mGo As CommandButton
Private WithEvents mCheck As CheckBox
Private WithEvents mChoices As ListBox
Private mFrame As Frame
Private WithEvents mLogo As Image
Private WithEvents mSpin As SpinButton
Private mStatus As Label
Private mPending1 As Label
Private mPending2 As Label
Private mPending3 As Label
Private mLog As String
Private mQueryCloseVeto As Boolean

Private Const OX_KEY_A As Integer = 65
Private Const OX_KEY_B As Integer = 66
Private Const OX_KEY_CTRL As Integer = 17
Private Const OX_KEY_G As Integer = 71
Private Const OX_KEY_V As Integer = 86
Private Const OX_KEY_SPACE As Integer = 32
Private Const OX_KEY_ENTER As Integer = 13
Private Const OX_KEY_ESCAPE As Integer = 27
Private Const OX_SHIFT_CTRL As Integer = 2
Private Const OX_SHIFT_ALT As Integer = 4

Public Sub Build()
    Set mForm = New UserForm
    mForm.Name = "full_surface_showcase"
    mForm.Caption = "OxForms Full Surface Showcase"
    mForm.Width = 640
    mForm.Height = 480

    Set mTitle = mForm.Controls.Add("Forms.Label.1", "TitleLabel")
    mTitle.Caption = "OxForms full-surface showcase: Label, TextBox, CommandButton, CheckBox, ListBox"
    mTitle.Left = 12
    mTitle.Top = 8
    mTitle.Width = 610
    mTitle.Height = 22
    mTitle.Core.FontSize = 10

    Dim Intro As Label
    Set Intro = mForm.Controls.Add("Forms.Label.1", "IntroLabel")
    Intro.Caption = "Current run proves render, input routing, TextBox caret/selection/editing, mutable helper events, validation, default/cancel, accelerator, clipboard, drop, and lifecycle."
    Intro.Left = 12
    Intro.Top = 34
    Intro.Width = 610
    Intro.Height = 18

    Dim TextCaption As Label
    Set TextCaption = mForm.Controls.Add("Forms.Label.1", "TextBoxCaption")
    TextCaption.Caption = "TextBox (focused at startup): type here; caret, selection, edit keys, copy/cut/paste/drop, and validation events are live"
    TextCaption.Left = 12
    TextCaption.Top = 64
    TextCaption.Width = 610
    TextCaption.Height = 18

    Set mInput = mForm.Controls.Add("Forms.TextBox.1", "InputField")
    mInput.Text = ""
    mInput.Left = 16
    mInput.Top = 88
    mInput.Width = 210
    mInput.Height = 24
    mInput.Core.TabIndex = 0

    Set mOk = mForm.Controls.Add("Forms.CommandButton.1", "OkButton")
    mOk.Caption = "&Log"
    mOk.Default = True
    mOk.Left = 244
    mOk.Top = 88
    mOk.Width = 70
    mOk.Height = 24
    mOk.Core.TabIndex = 1

    Set mCancel = mForm.Controls.Add("Forms.CommandButton.1", "CancelButton")
    mCancel.Caption = "Cancel"
    mCancel.Cancel = True
    mCancel.Left = 322
    mCancel.Top = 88
    mCancel.Width = 72
    mCancel.Height = 24
    mCancel.Core.TabIndex = 2

    Set mGo = mForm.Controls.Add("Forms.CommandButton.1", "GoButton")
    mGo.Caption = "&Go"
    mGo.Left = 402
    mGo.Top = 88
    mGo.Width = 70
    mGo.Height = 24
    mGo.Core.TabIndex = 3

    Set mCheck = mForm.Controls.Add("Forms.CheckBox.1", "CheckBox")
    mCheck.Caption = "CheckBox control (starts checked): Value, Change, Click, keyboard toggle, validation"
    mCheck.Value = True
    mCheck.Left = 16
    mCheck.Top = 126
    mCheck.Width = 520
    mCheck.Height = 26
    mCheck.Core.TabIndex = 4

    Set mChoices = mForm.Controls.Add("Forms.ListBox.1", "ChoicesList")
    mChoices.Left = 16
    mChoices.Top = 164
    mChoices.Width = 220
    mChoices.Height = 58
    mChoices.Core.TabIndex = 5
    mChoices.AddItem "Red"
    mChoices.AddItem "Green"
    mChoices.AddItem "Blue"
    mChoices.ListIndex = 0

    Set mFrame = mForm.Controls.Add("Forms.Frame.1", "FrameGroup")
    mFrame.Caption = "Frame"
    mFrame.Left = 260
    mFrame.Top = 164
    mFrame.Width = 170
    mFrame.Height = 58
    Dim FrameLabel As Label
    Set FrameLabel = mFrame.Controls.Add("Forms.Label.1", "FrameLabel")
    FrameLabel.Caption = "Nested child"
    FrameLabel.Left = 8
    FrameLabel.Top = 16
    FrameLabel.Width = 120
    FrameLabel.Height = 18

    Set mLogo = mForm.Controls.Add("Forms.Image.1", "LogoImage")
    mLogo.Left = 452
    mLogo.Top = 164
    mLogo.Width = 64
    mLogo.Height = 58
    mLogo.Core.BorderStyle = fmBorderStyleSingle
    mLogo.SetPictureReference "showcase-inline", 0, "showcase-demo-bytes", "4242"

    Set mSpin = mForm.Controls.Add("Forms.SpinButton.1", "RepeatSpin")
    mSpin.Left = 532
    mSpin.Top = 164
    mSpin.Width = 28
    mSpin.Height = 58
    mSpin.Min = 0
    mSpin.Max = 9
    mSpin.Value = 2
    mSpin.Core.TabIndex = 6

    Set mStatus = mForm.Controls.Add("Forms.Label.1", "StatusLabel")
    mStatus.Caption = "Ready. Run RunSelfTest, or interact with the controls."
    mStatus.Left = 16
    mStatus.Top = 232
    mStatus.Width = 600
    mStatus.Height = 24
    mStatus.Core.BackColor = &H2070C0
    mStatus.Core.ForeColor = &HFFFFFF
    mStatus.Core.FontSize = 9

    Set mPending1 = mForm.Controls.Add("Forms.Label.1", "PendingMorphLabel")
    mPending1.Caption = "Pending morph controls: OptionButton, ToggleButton, ComboBox"
    mPending1.Left = 16
    mPending1.Top = 278
    mPending1.Width = 600
    mPending1.Height = 18

    Set mPending2 = mForm.Controls.Add("Forms.Label.1", "PendingSimpleLabel")
    mPending2.Caption = "Pending simple controls: ScrollBar"
    mPending2.Left = 16
    mPending2.Top = 300
    mPending2.Width = 600
    mPending2.Height = 18

    Set mPending3 = mForm.Controls.Add("Forms.Label.1", "PendingContainerLabel")
    mPending3.Caption = "Pending containers: Frame, TabStrip, MultiPage/Page"
    mPending3.Left = 16
    mPending3.Top = 322
    mPending3.Width = 600
    mPending3.Height = 18

    Dim Usage As Label
    Set Usage = mForm.Controls.Add("Forms.Label.1", "UsageLabel")
    Usage.Caption = "Launch: cargo run -p oxforms-bootstrap -- showcase"
    Usage.Left = 16
    Usage.Top = 368
    Usage.Width = 600
    Usage.Height = 18

    Set mReducer = New OxReducer
    mReducer.Init mForm
    mForm.Render 96, 96

    ' Visible-app ergonomics: start with the TextBox focused so the caret is visible and
    ' immediate typing after launch goes through the same reducer path as a user click.
    mReducer.Dispatch "mousedown", 40, 98, 1, 0
    mReducer.Dispatch "mouseup", 40, 98, 1, 0
    mLog = ""
    mStatus.Caption = "TextBox has focus. Type now, or click the checked CheckBox/buttons."
    mForm.Render 96, 96
End Sub

' --- Reducer facade (driven by OxRuntime and by RunSelfTest) ---
Public Function Dispatch( _
        ByVal Kind As String, ByVal X As Long, ByVal Y As Long, _
        ByVal Button As Integer, ByVal Shift As Integer) As String
    Dispatch = mReducer.Dispatch(Kind, X, Y, Button, Shift)
End Function

Public Function DispatchKey(ByVal Kind As String, ByVal KeyCode As Integer, ByVal Shift As Integer) As String
    DispatchKey = mReducer.DispatchKey(Kind, KeyCode, Shift)
End Function

Public Function DispatchChar(ByVal Text As String) As String
    DispatchChar = mReducer.DispatchChar(Text)
End Function

Public Function DispatchDrop(ByVal Text As String) As String
    DispatchDrop = mReducer.DispatchDrop(Text)
End Function

Public Sub SetClipboardText(ByVal Text As String)
    mReducer.SetClipboardText Text
End Sub

Public Sub Render()
    mForm.Render 96, 96
End Sub

Public Function DispatchTimer(ByVal Slot As String, ByVal Fires As Long) As String
    If Slot = "auto_repeat" And mReducer.CaptureName = mSpin.Name Then
        mSpin.PerformRepeatTick Fires
        DispatchTimer = "repeat:" & mSpin.Name & ":" & CStr(Fires)
        mForm.Render 96, 96
        DispatchTimer = DispatchTimer & "|repaint"
    Else
        DispatchTimer = ""
    End If
End Function

Public Property Get FocusName() As String
    FocusName = mReducer.FocusName
End Property

Public Property Get InteractionStateSummary() As String
    InteractionStateSummary = mReducer.InteractionStateSummary
End Property

Public Property Get HandlerLog() As String
    HandlerLog = mLog
End Property

Public Property Get ControlCount() As Long
    ControlCount = mForm.Controls.Count
End Property

Public Property Get StatusCaption() As String
    StatusCaption = mStatus.Caption
End Property

Public Property Get InputText() As String
    InputText = mInput.Text
End Property

Public Property Get InputValue() As String
    InputValue = mInput.Value
End Property

Public Property Get InputSelStart() As Long
    InputSelStart = mInput.SelStart
End Property

Public Property Get InputSelLength() As Long
    InputSelLength = mInput.SelLength
End Property

Public Property Get InputSelText() As String
    InputSelText = mInput.SelText
End Property

Public Property Get TextBoxDiagnostics() As String
    Dim Control As IOxControl
    Set Control = mInput
    TextBoxDiagnostics = _
        "text=" & mInput.Text & _
        ";value=" & mInput.Value & _
        ";sel_start=" & CStr(mInput.SelStart) & _
        ";sel_length=" & CStr(mInput.SelLength) & _
        ";sel_text=" & mInput.SelText & _
        ";hide_selection=" & CStr(mInput.HideSelection) & _
        ";capabilities=" & mInput.Core.CapabilityDescriptor & _
        ";accessibility=" & Control.AccessibilityRole & "/" & Control.AccessibilityPatterns
End Property

Public Property Get CheckValue() As Boolean
    CheckValue = mCheck.Value
End Property

Public Property Get ListBoxDiagnostics() As String
    ListBoxDiagnostics = mChoices.Diagnostics
End Property

Public Property Get FrameDiagnostics() As String
    FrameDiagnostics = mFrame.Diagnostics
End Property

Public Property Get ImageDiagnostics() As String
    ImageDiagnostics = mLogo.Diagnostics
End Property

Public Property Get SpinButtonDiagnostics() As String
    SpinButtonDiagnostics = mSpin.Diagnostics
End Property

Public Property Get SpinValue() As Long
    SpinValue = mSpin.Value
End Property

Public Function DisableSpin() As String
    mSpin.Enabled = False
    mForm.Render 96, 96
    DisableSpin = mSpin.Diagnostics
End Function

Public Function HideSpin() As String
    mSpin.Visible = False
    mForm.Render 96, 96
    HideSpin = mSpin.Diagnostics
End Function

Public Property Get InteractionIndexBuildCount() As Long
    InteractionIndexBuildCount = mReducer.InteractionIndexBuildCount
End Property

Public Property Get InteractionIndexSummary() As String
    InteractionIndexSummary = mReducer.InteractionIndexSummary
End Property

Public Property Get AccessibilitySnapshot() As String
    AccessibilitySnapshot = mReducer.AccessibilitySnapshot
End Property

Public Property Get CapabilityCatalog() As String
    CapabilityCatalog = _
        "TitleLabel:" & mTitle.Core.CapabilityDescriptor & vbLf & _
        "InputField:" & mInput.Core.CapabilityDescriptor & vbLf & _
        "OkButton:" & mOk.Core.CapabilityDescriptor & vbLf & _
        "CancelButton:" & mCancel.Core.CapabilityDescriptor & vbLf & _
        "GoButton:" & mGo.Core.CapabilityDescriptor & vbLf & _
        "CheckBox:" & mCheck.Core.CapabilityDescriptor & vbLf & _
        "ChoicesList:" & mChoices.Core.CapabilityDescriptor & vbLf & _
        "FrameGroup:" & mFrame.Core.CapabilityDescriptor & vbLf & _
        "LogoImage:" & mLogo.Core.CapabilityDescriptor & vbLf & _
        "RepeatSpin:" & mSpin.Core.CapabilityDescriptor
End Property

Public Sub ClearLog()
    mLog = ""
    mStatus.Caption = "Log cleared"
End Sub

Public Function SurfaceCatalog() As String
    SurfaceCatalog = _
        "LIVE UserForm: Controls, Count, ControlByName, SuspendLayout, ResumeLayout, Render, lifecycle" & vbLf & _
        "LIVE Controls: Add, Item(index), Item(name), Count" & vbLf & _
        "LIVE Runtime foundation: capability descriptors, first-class InteractionManager diagnostics, accessibility snapshots, focus/tab/default/cancel/accelerator maps, hover/cursor/capture state, clipboard shortcuts" & vbLf & _
        "LIVE Label: Caption, geometry, Visible, Enabled; MouseDown, MouseUp, Click" & vbLf & _
        "LIVE TextBox: Text, Value, SelStart, SelLength, SelText, HideSelection, caret, selection, copy/cut/paste/drop, geometry, Visible, Enabled, TextBoxDiagnostics; Change, MouseDown, MouseUp, KeyDown, KeyPress, KeyUp, Enter, Exit, BeforeUpdate, AfterUpdate, BeforeDropOrPaste" & vbLf & _
        "LIVE CommandButton: Caption, Default, Cancel, geometry, Visible, Enabled; Click, MouseDown, MouseUp, KeyDown, KeyPress, KeyUp, Enter, Exit" & vbLf & _
        "LIVE CheckBox: Caption, Value, geometry, Visible, Enabled; Change, Click, MouseDown, MouseUp, KeyDown, KeyPress, KeyUp, Enter, Exit, BeforeUpdate, AfterUpdate" & vbLf & _
        "LIVE ListBox: AddItem, List(index), ListCount, ListIndex, Value, geometry, Visible, Enabled, ListBoxDiagnostics; Change, Click, MouseDown, MouseUp, KeyDown, KeyPress, KeyUp, Enter, Exit, BeforeUpdate, AfterUpdate; single-select rows" & vbLf & _
        "LIVE Frame: Caption, Controls.Add, child ownership, nested coordinates, clipped child Scene subtree, FrameDiagnostics" & vbLf & _
        "LIVE Image: Picture, PictureHandle, PictureSizeMode, geometry, Visible, Enabled, ImageDiagnostics; DrawImage placeholder render; MouseDown, MouseUp, Click" & vbLf & _
        "LIVE SpinButton: Value, Min, Max, SmallChange, geometry, Visible, Enabled, SpinButtonDiagnostics; SpinUp, SpinDown, Change, MouseDown, MouseUp, Enter, Exit; HostServices auto-repeat callback" & vbLf & _
        "PENDING OptionButton, ToggleButton, ComboBox, ScrollBar, TabStrip, MultiPage/Page"
End Function

Public Function RunSelfTest() As String
    ' The visible app starts focused in the TextBox and the CheckBox starts checked. Move focus
    ' to a button and reset the checkbox so the deterministic proof below keeps the same
    ' value/order assertions every run.
    DriveMouse 420, 98
    mCheck.Value = False
    ClearLog
    Append "SELFTEST.Begin"

    PerformInitialize
    PerformActivate

    DriveMouse 20, 16        ' Title Label: MouseDown/MouseUp/Click.
    DriveMouse 462, 184      ' Image: click-only, non-focusable DrawImage lane.
    DriveMouse 546, 174      ' SpinButton up half: single-step value/event path.
    DriveMouse 40, 98        ' TextBox: Enter/MouseDown/MouseUp.
    DriveKey OX_KEY_A, 0, "a"

    SetClipboardText " PASTE"
    DispatchKey "keydown", OX_KEY_CTRL, OX_SHIFT_CTRL
    DispatchKey "keydown", OX_KEY_V, OX_SHIFT_CTRL
    DispatchDrop " DROP"

    DispatchKey "keydown", OX_KEY_ENTER, 0
    DriveKey OX_KEY_B, 0, "b"    ' CommandButton KeyDown/KeyPress/KeyUp while OK focused.
    DriveMouse 260, 98           ' CommandButton mouse events + Click.

    DriveMouse 40, 136           ' CheckBox mouse focus/toggle.
    DispatchKey "keydown", OX_KEY_SPACE, 0
    DispatchKey "keyup", OX_KEY_SPACE, 0
    DispatchChar "c"

    DriveMouse 40, 192           ' Dirty CheckBox focus-out; ListBox mouse focus/select.
    DispatchKey "keydown", 40, 0
    DispatchKey "keyup", 40, 0
    DispatchChar "l"

    DriveMouse 40, 98            ' Dirty ListBox focus-out: BeforeUpdate/AfterUpdate/Exit.
    DispatchKey "keydown", OX_KEY_ESCAPE, 0
    DispatchKey "keydown", OX_KEY_G, OX_SHIFT_ALT

    PerformDeactivate
    PerformQueryClose 1
    PerformTerminate

    Append "SELFTEST.Pass"
    mStatus.Caption = "Self-test pass: " & CStr(mForm.Controls.Count) & " live controls/pending rows"
    mForm.Render 96, 96
    RunSelfTest = "PASS controls=" & CStr(mForm.Controls.Count) & ";lines=" & CStr(LogLineCount())
End Function

Private Sub DriveMouse(ByVal X As Long, ByVal Y As Long)
    Dispatch "mousedown", X, Y, 1, 0
    Dispatch "mouseup", X, Y, 1, 0
End Sub

Private Sub DriveKey(ByVal KeyCode As Integer, ByVal Shift As Integer, ByVal Text As String)
    DispatchKey "keydown", KeyCode, Shift
    If Len(Text) > 0 Then DispatchChar Text
    DispatchKey "keyup", KeyCode, Shift
End Sub

Private Function LogLineCount() As Long
    If Len(mLog) = 0 Then Exit Function
    Dim I As Long
    LogLineCount = 1
    For I = 1 To Len(mLog)
        If Mid$(mLog, I, 1) = vbLf Then LogLineCount = LogLineCount + 1
    Next I
End Function

' --- Form-level lifecycle dispatch surface ---
Public Sub PerformInitialize()
    UserForm_Initialize
End Sub
Public Sub PerformActivate()
    UserForm_Activate
End Sub
Public Sub PerformDeactivate()
    UserForm_Deactivate
End Sub
Public Sub PerformTerminate()
    UserForm_Terminate
End Sub
Public Function PerformQueryClose(ByVal CloseMode As Integer) As Integer
    Dim Cancel As ReturnInteger
    Set Cancel = New ReturnInteger
    Cancel.Value = 0
    UserForm_QueryClose Cancel, CloseMode
    PerformQueryClose = Cancel.Value
End Function

Public Sub ArmQueryCloseVeto()
    mQueryCloseVeto = True
End Sub

' --- Event sinks: Label ---
Private Sub mTitle_MouseDown(ByVal Button As Integer, ByVal Shift As Integer, ByVal X As Single, ByVal Y As Single)
    Append "Label.MouseDown"
End Sub
Private Sub mTitle_MouseUp(ByVal Button As Integer, ByVal Shift As Integer, ByVal X As Single, ByVal Y As Single)
    Append "Label.MouseUp"
End Sub
Private Sub mTitle_Click()
    Append "Label.Click"
End Sub

' --- Event sinks: TextBox ---
Private Sub mInput_Enter()
    Append "TextBox.Enter"
End Sub
Private Sub mInput_Exit(ByVal Cancel As ReturnBoolean)
    Append "TextBox.Exit"
End Sub
Private Sub mInput_BeforeUpdate(ByVal Cancel As ReturnBoolean)
    Append "TextBox.BeforeUpdate"
End Sub
Private Sub mInput_AfterUpdate()
    Append "TextBox.AfterUpdate"
End Sub
Private Sub mInput_Change()
    Append "TextBox.Change"
End Sub
Private Sub mInput_MouseDown(ByVal Button As Integer, ByVal Shift As Integer, ByVal X As Single, ByVal Y As Single)
    Append "TextBox.MouseDown"
End Sub
Private Sub mInput_MouseUp(ByVal Button As Integer, ByVal Shift As Integer, ByVal X As Single, ByVal Y As Single)
    Append "TextBox.MouseUp"
End Sub
Private Sub mInput_KeyDown(ByVal KeyCode As ReturnInteger, ByVal Shift As Integer)
    Append "TextBox.KeyDown:" & CStr(KeyCode.Value)
End Sub
Private Sub mInput_KeyUp(ByVal KeyCode As ReturnInteger, ByVal Shift As Integer)
    Append "TextBox.KeyUp:" & CStr(KeyCode.Value)
End Sub
Private Sub mInput_KeyPress(ByVal KeyAscii As ReturnInteger)
    Append "TextBox.KeyPress:" & CStr(KeyAscii.Value)
End Sub
Private Sub mInput_BeforeDropOrPaste(ByVal Cancel As ReturnBoolean, ByVal Action As Integer, ByVal Shift As Integer)
    Append "TextBox.BeforeDropOrPaste:" & CStr(Action)
End Sub

' --- Event sinks: CommandButton family ---
Private Sub mOk_Enter()
    Append "CommandButton.Enter"
End Sub
Private Sub mOk_Exit(ByVal Cancel As ReturnBoolean)
    Append "CommandButton.Exit"
End Sub
Private Sub mOk_Click()
    Append "CommandButton.Click"
End Sub
Private Sub mOk_MouseDown(ByVal Button As Integer, ByVal Shift As Integer, ByVal X As Single, ByVal Y As Single)
    Append "CommandButton.MouseDown"
End Sub
Private Sub mOk_MouseUp(ByVal Button As Integer, ByVal Shift As Integer, ByVal X As Single, ByVal Y As Single)
    Append "CommandButton.MouseUp"
End Sub
Private Sub mOk_KeyDown(ByVal KeyCode As ReturnInteger, ByVal Shift As Integer)
    Append "CommandButton.KeyDown:" & CStr(KeyCode.Value)
End Sub
Private Sub mOk_KeyUp(ByVal KeyCode As ReturnInteger, ByVal Shift As Integer)
    Append "CommandButton.KeyUp:" & CStr(KeyCode.Value)
End Sub
Private Sub mOk_KeyPress(ByVal KeyAscii As ReturnInteger)
    Append "CommandButton.KeyPress:" & CStr(KeyAscii.Value)
End Sub

Private Sub mCancel_Click()
    Append "CancelButton.Click"
End Sub

Private Sub mGo_Enter()
    Append "AcceleratorButton.Enter"
End Sub
Private Sub mGo_Click()
    Append "AcceleratorButton.Click"
End Sub

' --- Event sinks: CheckBox ---
Private Sub mCheck_Enter()
    Append "CheckBox.Enter"
End Sub
Private Sub mCheck_Exit(ByVal Cancel As ReturnBoolean)
    Append "CheckBox.Exit"
End Sub
Private Sub mCheck_BeforeUpdate(ByVal Cancel As ReturnBoolean)
    Append "CheckBox.BeforeUpdate"
End Sub
Private Sub mCheck_AfterUpdate()
    Append "CheckBox.AfterUpdate"
End Sub
Private Sub mCheck_Change()
    Append "CheckBox.Change=" & CStr(mCheck.Value)
End Sub
Private Sub mCheck_Click()
    Append "CheckBox.Click=" & CStr(mCheck.Value)
End Sub
Private Sub mCheck_MouseDown(ByVal Button As Integer, ByVal Shift As Integer, ByVal X As Single, ByVal Y As Single)
    Append "CheckBox.MouseDown"
End Sub
Private Sub mCheck_MouseUp(ByVal Button As Integer, ByVal Shift As Integer, ByVal X As Single, ByVal Y As Single)
    Append "CheckBox.MouseUp"
End Sub
Private Sub mCheck_KeyDown(ByVal KeyCode As ReturnInteger, ByVal Shift As Integer)
    Append "CheckBox.KeyDown:" & CStr(KeyCode.Value)
End Sub
Private Sub mCheck_KeyUp(ByVal KeyCode As ReturnInteger, ByVal Shift As Integer)
    Append "CheckBox.KeyUp:" & CStr(KeyCode.Value)
End Sub
Private Sub mCheck_KeyPress(ByVal KeyAscii As ReturnInteger)
    Append "CheckBox.KeyPress:" & CStr(KeyAscii.Value)
End Sub

' --- Event sinks: ListBox ---
Private Sub mChoices_Enter()
    Append "ListBox.Enter"
End Sub
Private Sub mChoices_Exit(ByVal Cancel As ReturnBoolean)
    Append "ListBox.Exit"
End Sub
Private Sub mChoices_BeforeUpdate(ByVal Cancel As ReturnBoolean)
    Append "ListBox.BeforeUpdate"
End Sub
Private Sub mChoices_AfterUpdate()
    Append "ListBox.AfterUpdate"
End Sub
Private Sub mChoices_Change()
    Append "ListBox.Change:" & mChoices.Value
End Sub
Private Sub mChoices_Click()
    Append "ListBox.Click:" & mChoices.Value
End Sub
Private Sub mChoices_MouseDown(ByVal Button As Integer, ByVal Shift As Integer, ByVal X As Single, ByVal Y As Single)
    Append "ListBox.MouseDown"
End Sub
Private Sub mChoices_MouseUp(ByVal Button As Integer, ByVal Shift As Integer, ByVal X As Single, ByVal Y As Single)
    Append "ListBox.MouseUp"
End Sub
Private Sub mChoices_KeyDown(ByVal KeyCode As ReturnInteger, ByVal Shift As Integer)
    Append "ListBox.KeyDown:" & CStr(KeyCode.Value)
End Sub
Private Sub mChoices_KeyUp(ByVal KeyCode As ReturnInteger, ByVal Shift As Integer)
    Append "ListBox.KeyUp:" & CStr(KeyCode.Value)
End Sub
Private Sub mChoices_KeyPress(ByVal KeyAscii As ReturnInteger)
    Append "ListBox.KeyPress:" & CStr(KeyAscii.Value)
End Sub

' --- Event sinks: Image ---
Private Sub mLogo_MouseDown(ByVal Button As Integer, ByVal Shift As Integer, ByVal X As Single, ByVal Y As Single)
    Append "Image.MouseDown"
End Sub
Private Sub mLogo_MouseUp(ByVal Button As Integer, ByVal Shift As Integer, ByVal X As Single, ByVal Y As Single)
    Append "Image.MouseUp"
End Sub
Private Sub mLogo_Click()
    Append "Image.Click"
End Sub

' --- Event sinks: SpinButton ---
Private Sub mSpin_Enter()
    Append "SpinButton.Enter"
End Sub
Private Sub mSpin_Exit(ByVal Cancel As ReturnBoolean)
    Append "SpinButton.Exit"
End Sub
Private Sub mSpin_MouseDown(ByVal Button As Integer, ByVal Shift As Integer, ByVal X As Single, ByVal Y As Single)
    Append "SpinButton.MouseDown"
End Sub
Private Sub mSpin_MouseUp(ByVal Button As Integer, ByVal Shift As Integer, ByVal X As Single, ByVal Y As Single)
    Append "SpinButton.MouseUp"
End Sub
Private Sub mSpin_SpinUp()
    Append "SpinButton.SpinUp=" & CStr(mSpin.Value)
End Sub
Private Sub mSpin_SpinDown()
    Append "SpinButton.SpinDown=" & CStr(mSpin.Value)
End Sub
Private Sub mSpin_Change()
    Append "SpinButton.Change=" & CStr(mSpin.Value)
End Sub

' --- Form event handlers exposed through Perform* ---
Private Sub UserForm_Initialize()
    Append "UserForm.Initialize"
End Sub
Private Sub UserForm_Activate()
    Append "UserForm.Activate"
End Sub
Private Sub UserForm_Deactivate()
    Append "UserForm.Deactivate"
End Sub
Private Sub UserForm_Terminate()
    Append "UserForm.Terminate"
End Sub
Private Sub UserForm_QueryClose(ByVal Cancel As ReturnInteger, ByVal CloseMode As Integer)
    Append "UserForm.QueryClose:" & CStr(CloseMode)
    If mQueryCloseVeto Then Cancel.Value = -1
End Sub

Private Sub Append(ByVal Line As String)
    If Len(mLog) > 0 Then mLog = mLog & vbLf
    mLog = mLog & Line
    If Not mStatus Is Nothing Then mStatus.Caption = "Last event: " & Line
End Sub
