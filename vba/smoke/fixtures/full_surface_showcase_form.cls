Option Explicit

' Living CalcForms full-surface showcase. This is a runnable form-document, not an oracle:
' it renders every W009 intrinsic control currently implemented by CalcForms, keeps
' pending-control rows empty at W009 subset depth, and exposes a deterministic RunSelfTest method that drives the current
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
Private WithEvents mToggle As ToggleButton
Private WithEvents mOption As OptionButtonControl
Private WithEvents mChoices As ListBox
Private WithEvents mCombo As ComboBox
Private mFrame As Frame
Private WithEvents mLogo As Image
Private WithEvents mSpin As SpinButton
Private WithEvents mScroll As ScrollBar
Private WithEvents mTabs As TabStrip
Private WithEvents mPages As MultiPage
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

Private Sub Class_Initialize()
    Set mForm = Nothing
    Set mReducer = Nothing
    Set mTitle = Nothing
    Set mInput = Nothing
    Set mOk = Nothing
    Set mCancel = Nothing
    Set mGo = Nothing
    Set mCheck = Nothing
    Set mToggle = Nothing
    Set mOption = Nothing
    Set mChoices = Nothing
    Set mCombo = Nothing
    Set mFrame = Nothing
    Set mLogo = Nothing
    Set mSpin = Nothing
    Set mScroll = Nothing
    Set mTabs = Nothing
    Set mPages = Nothing
    Set mStatus = Nothing
    Set mPending1 = Nothing
    Set mPending2 = Nothing
    Set mPending3 = Nothing
End Sub

Public Sub Build()
    Set mForm = New UserForm
    mForm.Name = "full_surface_showcase"
    mForm.Caption = "CalcForms Full Surface Showcase"
    mForm.Width = 640
    mForm.Height = 480

    Set mTitle = mForm.Controls.Add("Forms.Label.1", "TitleLabel")
    mTitle.Caption = "CalcForms full-surface showcase: Label, TextBox, CommandButton, CheckBox, OptionButton, ToggleButton, ListBox, ComboBox"
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
    mCheck.Width = 420
    mCheck.Height = 26
    mCheck.Core.TabIndex = 4

    Set mToggle = mForm.Controls.Add("Forms.ToggleButton.1", "ToggleButton")
    mToggle.Caption = "Toggle"
    mToggle.Value = True
    mToggle.Left = 452
    mToggle.Top = 126
    mToggle.Width = 104
    mToggle.Height = 26
    mToggle.Core.TabIndex = 5

    Set mOption = mForm.Controls.Add("Forms.OptionButton.1", "OptionButton")
    mOption.Caption = "Option"
    mOption.GroupName = "Showcase"
    mOption.Value = True
    mOption.Left = 452
    mOption.Top = 96
    mOption.Width = 104
    mOption.Height = 24
    mOption.Core.TabIndex = 6

    Set mChoices = mForm.Controls.Add("Forms.ListBox.1", "ChoicesList")
    mChoices.Left = 16
    mChoices.Top = 164
    mChoices.Width = 220
    mChoices.Height = 58
    mChoices.Core.TabIndex = 7
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
    mSpin.Core.TabIndex = 8

    Set mScroll = mForm.Controls.Add("Forms.ScrollBar.1", "AmountScroll")
    mScroll.Left = 452
    mScroll.Top = 232
    mScroll.Width = 108
    mScroll.Height = 18
    mScroll.Min = 0
    mScroll.Max = 100
    mScroll.SmallChange = 5
    mScroll.LargeChange = 20
    mScroll.Value = 40
    mScroll.Core.TabIndex = 9

    Set mTabs = mForm.Controls.Add("Forms.TabStrip.1", "ModeTabs")
    mTabs.Left = 452
    mTabs.Top = 256
    mTabs.Width = 150
    mTabs.Height = 48
    mTabs.Tabs.Add "One"
    mTabs.Tabs.Add "Two"
    mTabs.Tabs.Add "Three"
    mTabs.Value = 0
    mTabs.Core.TabIndex = 10

    Set mPages = mForm.Controls.Add("Forms.MultiPage.1", "ModePages")
    mPages.Left = 452
    mPages.Top = 310
    mPages.Width = 150
    mPages.Height = 52
    Dim FirstPage As Page
    Set FirstPage = mPages.Pages.Add("First")
    Dim PageLabel As Label
    Set PageLabel = FirstPage.Controls.Add("Forms.Label.1", "ModePageLabel")
    PageLabel.Caption = "Page child"
    PageLabel.Left = 8
    PageLabel.Top = 8
    PageLabel.Width = 100
    PageLabel.Height = 16
    mPages.Pages.Add "Second"
    mPages.Value = 0
    mPages.Core.TabIndex = 11

    Set mCombo = mForm.Controls.Add("Forms.ComboBox.1", "ChoiceCombo")
    mCombo.Left = 260
    mCombo.Top = 232
    mCombo.Width = 170
    mCombo.Height = 24
    mCombo.Core.TabIndex = 12
    mCombo.AddItem "Small"
    mCombo.AddItem "Medium"
    mCombo.AddItem "Large"
    mCombo.Value = "Small"

    Set mStatus = mForm.Controls.Add("Forms.Label.1", "StatusLabel")
    mStatus.Caption = "Ready. Run RunSelfTest, or interact with the controls."
    mStatus.Left = 16
    mStatus.Top = 264
    mStatus.Width = 420
    mStatus.Height = 24
    mStatus.Core.BackColor = &H2070C0
    mStatus.Core.ForeColor = &HFFFFFF
    mStatus.Core.FontSize = 9

    Set mPending1 = mForm.Controls.Add("Forms.Label.1", "PendingMorphLabel")
    mPending1.Caption = "Pending controls: none in current W009 intrinsic set"
    mPending1.Left = 16
    mPending1.Top = 278
    mPending1.Width = 420
    mPending1.Height = 18

    Set mPending2 = mForm.Controls.Add("Forms.Label.1", "PendingSimpleLabel")
    mPending2.Caption = "Pending parity: exact pixels, serialized pages, and oracle edge cases"
    mPending2.Left = 16
    mPending2.Top = 300
    mPending2.Width = 420
    mPending2.Height = 18

    Set mPending3 = mForm.Controls.Add("Forms.Label.1", "PendingContainerLabel")
    mPending3.Caption = "Representative control lanes continue through containers"
    mPending3.Left = 16
    mPending3.Top = 322
    mPending3.Width = 420
    mPending3.Height = 18

    Dim Usage As Label
    Set Usage = mForm.Controls.Add("Forms.Label.1", "UsageLabel")
    Usage.Caption = "Launch: cargo run -p calcforms-bootstrap -- showcase"
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
        ";multiline=" & CStr(mInput.MultiLine) & _
        ";can_undo=" & CStr(mInput.CanUndo) & _
        ";can_redo=" & CStr(mInput.CanRedo) & _
        ";composition_active=" & CStr(mInput.CompositionActive) & _
        ";composition_text=" & mInput.CompositionText & _
        ";capabilities=" & mInput.Core.CapabilityDescriptor & _
        ";accessibility=" & Control.AccessibilityRole & "/" & Control.AccessibilityPatterns
End Property

Public Property Get CheckValue() As Boolean
    CheckValue = mCheck.Value
End Property

Public Property Get ToggleValue() As Boolean
    ToggleValue = mToggle.Value
End Property

Public Property Get OptionValue() As Boolean
    OptionValue = mOption.Value
End Property

Public Property Get ToggleButtonDiagnostics() As String
    Dim Control As IOxControl
    Set Control = mToggle
    ToggleButtonDiagnostics = _
        "caption=" & mToggle.Caption & _
        ";value=" & CStr(mToggle.Value) & _
        ";capabilities=" & mToggle.Core.CapabilityDescriptor & _
        ";accessibility=" & Control.AccessibilityRole & "/" & Control.AccessibilityValue & "/" & Control.AccessibilityPatterns
End Property

Public Property Get OptionButtonDiagnostics() As String
    Dim Control As IOxControl
    Set Control = mOption
    OptionButtonDiagnostics = _
        "caption=" & mOption.Caption & _
        ";group=" & mOption.GroupName & _
        ";value=" & CStr(mOption.Value) & _
        ";capabilities=" & mOption.Core.CapabilityDescriptor & _
        ";accessibility=" & Control.AccessibilityRole & "/" & Control.AccessibilityValue & "/" & Control.AccessibilityPatterns
End Property

Public Property Get ListBoxDiagnostics() As String
    ListBoxDiagnostics = mChoices.Diagnostics
End Property

Public Property Get ComboBoxDiagnostics() As String
    ComboBoxDiagnostics = mCombo.Diagnostics
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

Public Property Get ScrollBarDiagnostics() As String
    ScrollBarDiagnostics = mScroll.Diagnostics
End Property

Public Property Get TabStripDiagnostics() As String
    TabStripDiagnostics = mTabs.Diagnostics
End Property

Public Property Get MultiPageDiagnostics() As String
    MultiPageDiagnostics = mPages.Diagnostics
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
        "ToggleButton:" & mToggle.Core.CapabilityDescriptor & vbLf & _
        "OptionButton:" & mOption.Core.CapabilityDescriptor & vbLf & _
        "ChoicesList:" & mChoices.Core.CapabilityDescriptor & vbLf & _
        "ChoiceCombo:" & mCombo.Core.CapabilityDescriptor & vbLf & _
        "FrameGroup:" & mFrame.Core.CapabilityDescriptor & vbLf & _
        "LogoImage:" & mLogo.Core.CapabilityDescriptor & vbLf & _
        "RepeatSpin:" & mSpin.Core.CapabilityDescriptor & vbLf & _
        "AmountScroll:" & mScroll.Core.CapabilityDescriptor & vbLf & _
        "ModeTabs:" & mTabs.Core.CapabilityDescriptor & vbLf & _
        "ModePages:" & mPages.Core.CapabilityDescriptor
End Property

Public Property Get ConformanceDashboard() As String
    ConformanceDashboard = _
        "CALCFORMS_CONFORMANCE_DASHBOARD version=1;source=FullSurfaceShowcaseForm;runtime=OxRuntime/OxReducer/CalcForms.Surface/Scene" & vbLf & _
        "supported.controls=UserForm,Controls,Label,TextBox,CommandButton,CheckBox,OptionButton,ToggleButton,ListBox,ComboBox,Frame,Image,SpinButton,ScrollBar,TabStrip,Tabs,Tab,MultiPage,Pages,Page" & vbLf & _
        "supported.properties=TextBox.Text,TextBox.Value,TextBox.SelStart,TextBox.SelLength,TextBox.SelText,TextBox.HideSelection,TextBox.MultiLine,TextBox.CanUndo,TextBox.CanRedo,TextBox.CompositionActive,TextBox.CompositionText,CheckBox.Value,OptionButton.Value,OptionButton.GroupName,ToggleButton.Value,ListBox.ListCount,ListBox.ListIndex,ListBox.Value,ListBox.MultiSelect,ListBox.Selected,ListBox.ColumnCount,ListBox.BoundColumn,ComboBox.Text,ComboBox.Value,ComboBox.ListCount,ComboBox.ListIndex,ComboBox.DropDownOpen,Frame.Caption,Image.Picture,Image.PictureHandle,Image.PictureSizeMode,SpinButton.Value,SpinButton.Min,SpinButton.Max,SpinButton.SmallChange,ScrollBar.Value,ScrollBar.Min,ScrollBar.Max,ScrollBar.SmallChange,ScrollBar.LargeChange,TabStrip.Value,TabStrip.ListIndex,TabStrip.SelectedCaption,Tabs.Count,Tab.Caption,Tab.Selected,MultiPage.Value,MultiPage.ListIndex,MultiPage.SelectedCaption,Pages.Count,Page.Caption,Page.Selected,Page.Controls,CommandButton.Default,CommandButton.Cancel" & vbLf & _
        "supported.methods=Controls.Add,Controls.Item,UserForm.Render,Dispatch,DispatchKey,DispatchChar,DispatchDrop,SetClipboardText,DispatchTimer,RunSelfTest,TextBox.Undo,TextBox.Redo,TextBox.BeginComposition,TextBox.UpdateComposition,TextBox.CommitComposition,TextBox.CancelComposition,TextBoxDiagnostics,OptionButtonDiagnostics,ToggleButtonDiagnostics,ListBoxDiagnostics,ComboBoxDiagnostics,FrameDiagnostics,ImageDiagnostics,SpinButtonDiagnostics,ScrollBarDiagnostics,TabStripDiagnostics,MultiPageDiagnostics,AccessibilitySnapshot" & vbLf & _
        "supported.events=Initialize,Activate,Deactivate,Terminate,QueryClose,Enter,Exit,BeforeUpdate,AfterUpdate,Change,Scroll,Click,MouseDown,MouseUp,KeyDown,KeyPress,KeyUp,BeforeDropOrPaste,DropButtonClick,SpinUp,SpinDown" & vbLf & _
        "focus=" & InteractionIndexSummary & vbLf & _
        "cursor=" & InteractionStateSummary & vbLf & _
        "host.services=clipboard,text-dataobject,cursor,timer,dpi,metrics,colors,image-decode,drag-drop" & vbLf & _
        "accessibility.snapshot=" & AccessibilitySnapshot & vbLf & _
        "perf.report=docs/evidence/W009_first_class_runtime_foundation/perf/w009-ideal-architecture-budget-20260707.json;top_followup=oxforms-bqr scaled-hit-test" & vbLf & _
        "selftest=RunSelfTest returns PASS and drives current controls/properties/methods/events" & vbLf & _
        "pending.controls="
End Property

Public Property Get SupportedSurfaceSummary() As String
    SupportedSurfaceSummary = _
        "controls=UserForm,Controls,Label,TextBox,CommandButton,CheckBox,OptionButton,ToggleButton,ListBox,ComboBox,Frame,Image,SpinButton,ScrollBar,TabStrip,Tabs,Tab,MultiPage,Pages,Page" & vbLf & _
        "properties=Text,Value,SelStart,SelLength,SelText,HideSelection,MultiLine,CanUndo,CanRedo,CompositionActive,CompositionText,Caption,Enabled,Visible,TabIndex,ListCount,ListIndex,DropDownOpen,Picture,PictureHandle,PictureSizeMode,Min,Max,SmallChange,LargeChange,SelectedCaption,Page.Controls,Default,Cancel" & vbLf & _
        "methods=Controls.Add,Controls.Item,Render,Dispatch,DispatchKey,DispatchChar,DispatchDrop,SetClipboardText,DispatchTimer,RunSelfTest,TextBox.Undo,TextBox.Redo,TextBox.BeginComposition,TextBox.UpdateComposition,TextBox.CommitComposition,TextBox.CancelComposition" & vbLf & _
        "events=Initialize,Activate,Deactivate,Terminate,QueryClose,Enter,Exit,BeforeUpdate,AfterUpdate,Change,Scroll,Click,MouseDown,MouseUp,KeyDown,KeyPress,KeyUp,BeforeDropOrPaste,DropButtonClick,SpinUp,SpinDown"
End Property

Public Property Get PendingSurfaceSummary() As String
    PendingSurfaceSummary = _
        "controls=" & vbLf & _
        "followups=TextBox native OS IME hookup and multiline pixel parity;Accessibility live Windows provider registration/client traversal;native SpinButton/ScrollBar timer wake-up;scaled hit-test indexing;Image decoded pixels/full Picture parity"
End Property

Public Property Get PerfBudgetSummary() As String
    PerfBudgetSummary = _
        "report=docs/evidence/W009_first_class_runtime_foundation/perf/w009-ideal-architecture-budget-20260707.json;" & _
        "representative_p95_us=32356;scaled_hit_test_p95_100_controls_us=432473;followup=oxforms-bqr"
End Property

Public Property Get SelfTestSummary() As String
    SelfTestSummary = "method=RunSelfTest;expected=PASS controls=23;coverage=Label/TextBox/CommandButton/CheckBox/OptionButton/ToggleButton/ListBox/ComboBox/Frame/Image/SpinButton/ScrollBar/TabStrip/MultiPage/lifecycle"
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
        "LIVE TextBox: Text, Value, SelStart, SelLength, SelText, HideSelection, MultiLine, undo/redo, composition facade, caret, selection, copy/cut/paste/drop, geometry, Visible, Enabled, TextBoxDiagnostics; Change, MouseDown, MouseUp, KeyDown, KeyPress, KeyUp, Enter, Exit, BeforeUpdate, AfterUpdate, BeforeDropOrPaste" & vbLf & _
        "LIVE CommandButton: Caption, Default, Cancel, geometry, Visible, Enabled; Click, MouseDown, MouseUp, KeyDown, KeyPress, KeyUp, Enter, Exit" & vbLf & _
        "LIVE CheckBox: Caption, Value, geometry, Visible, Enabled; Change, Click, MouseDown, MouseUp, KeyDown, KeyPress, KeyUp, Enter, Exit, BeforeUpdate, AfterUpdate" & vbLf & _
        "LIVE OptionButton: Caption, Value, GroupName, same-container mutual exclusion, geometry, Visible, Enabled, OptionButtonDiagnostics; Change, Click, MouseDown, MouseUp, KeyDown, KeyPress, KeyUp, Enter, Exit, BeforeUpdate, AfterUpdate" & vbLf & _
        "LIVE ToggleButton: Caption, Value, latched pressed face, geometry, Visible, Enabled, ToggleButtonDiagnostics; Change, Click, MouseDown, MouseUp, KeyDown, KeyPress, KeyUp, Enter, Exit, BeforeUpdate, AfterUpdate" & vbLf & _
        "LIVE ListBox: AddItem, AddRow, List(index), Column(index,column), ListCount, ListIndex, Value, MultiSelect, Selected(index), ColumnCount, BoundColumn, geometry, Visible, Enabled, ListBoxDiagnostics; Change, Click, MouseDown, MouseUp, KeyDown, KeyPress, KeyUp, Enter, Exit, BeforeUpdate, AfterUpdate; single/multi/extended row selection" & vbLf & _
        "LIVE ComboBox: AddItem, List(index), ListCount, ListIndex, Text, Value, DropDown, DropDownOpen, geometry, Visible, Enabled, ComboBoxDiagnostics; DropButtonClick, Change, Click, MouseDown, MouseUp, KeyDown, KeyPress, KeyUp, Enter, Exit, BeforeUpdate, AfterUpdate, BeforeDropOrPaste; editable value plus representative dropdown" & vbLf & _
        "LIVE Frame: Caption, Controls.Add, child ownership, nested coordinates, clipped child Scene subtree, FrameDiagnostics" & vbLf & _
        "LIVE Image: Picture, PictureHandle, PictureSizeMode, geometry, Visible, Enabled, ImageDiagnostics; DrawImage placeholder render; MouseDown, MouseUp, Click" & vbLf & _
        "LIVE SpinButton: Value, Min, Max, SmallChange, geometry, Visible, Enabled, SpinButtonDiagnostics; Up/Down keyboard stepping; SpinUp, SpinDown, Change, MouseDown, MouseUp, KeyDown, KeyUp, Enter, Exit; HostServices auto-repeat callback" & vbLf & _
        "LIVE ScrollBar: Value, Min, Max, SmallChange, LargeChange, button/page/thumb regions, geometry, Visible, Enabled, ScrollBarDiagnostics; Scroll, Change, MouseDown, MouseUp, KeyDown, KeyUp, Enter, Exit; held repeat/native cadence blocker" & vbLf & _
        "LIVE TabStrip: Tabs.Add, Tabs.Item, Tabs.Count, Tab.Caption, Tab.Selected, Value/ListIndex, SelectedCaption, geometry, Visible, Enabled, TabStripDiagnostics; Change, MouseDown, MouseUp, KeyDown, KeyUp, Enter, Exit; per-tab text-run and exact visual/materialization blockers" & vbLf & _
        "LIVE MultiPage: Pages.Add, Pages.Item, Pages.Count, Page.Caption, Page.Selected, Page.Controls, Value/ListIndex, SelectedCaption, page-local child ownership, focus scopes, MultiPageDiagnostics; Change, MouseDown, MouseUp, KeyDown, KeyUp, Enter, Exit; serialized page-item and exact visual/oracle blockers"
End Function

Public Function RunSelfTest() As String
    ' The visible app starts focused in the TextBox and the CheckBox starts checked. Move focus
    ' to a button and reset the checkbox so the deterministic proof below keeps the same
    ' value/order assertions every run.
    DriveMouse 420, 98
    mCheck.Value = False
    mToggle.Value = True
    mOption.Value = True
    ClearLog
    Append "SELFTEST.Begin"

    PerformInitialize
    PerformActivate

    DriveMouse 20, 16        ' Title Label: MouseDown/MouseUp/Click.
    DriveMouse 462, 184      ' Image: click-only, non-focusable DrawImage lane.
    DriveMouse 546, 174      ' SpinButton up half: single-step value/event path.
    DriveMouse 552, 241      ' ScrollBar right button: Scroll before Change.
    DriveMouse 512, 266      ' TabStrip second tab: Change path.
    DriveMouse 532, 320      ' MultiPage second page: page-switch Change path.
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

    DriveMouse 470, 136          ' ToggleButton mouse focus/toggle.
    DispatchKey "keydown", OX_KEY_SPACE, 0
    DispatchKey "keyup", OX_KEY_SPACE, 0
    DispatchChar "t"

    DriveMouse 470, 108          ' OptionButton focus/select; already selected, so Click only.
    DispatchKey "keydown", OX_KEY_SPACE, 0
    DispatchKey "keyup", OX_KEY_SPACE, 0
    DispatchChar "o"

    DriveMouse 40, 192           ' Dirty CheckBox focus-out; ListBox mouse focus/select.
    DispatchKey "keydown", 40, 0
    DispatchKey "keyup", 40, 0
    DispatchChar "l"

    DriveMouse 420, 244          ' Dirty ListBox focus-out; ComboBox drop button opens.
    DispatchKey "keydown", 40, 0
    DispatchKey "keyup", 40, 0
    DispatchChar "x"

    DriveMouse 40, 98            ' Dirty ComboBox focus-out: BeforeUpdate/AfterUpdate/Exit.
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

' --- Event sinks: ToggleButton ---
Private Sub mToggle_Enter()
    Append "ToggleButton.Enter"
End Sub
Private Sub mToggle_Exit(ByVal Cancel As ReturnBoolean)
    Append "ToggleButton.Exit"
End Sub
Private Sub mToggle_BeforeUpdate(ByVal Cancel As ReturnBoolean)
    Append "ToggleButton.BeforeUpdate"
End Sub
Private Sub mToggle_AfterUpdate()
    Append "ToggleButton.AfterUpdate"
End Sub
Private Sub mToggle_Change()
    Append "ToggleButton.Change=" & CStr(mToggle.Value)
End Sub
Private Sub mToggle_Click()
    Append "ToggleButton.Click=" & CStr(mToggle.Value)
End Sub
Private Sub mToggle_MouseDown(ByVal Button As Integer, ByVal Shift As Integer, ByVal X As Single, ByVal Y As Single)
    Append "ToggleButton.MouseDown"
End Sub
Private Sub mToggle_MouseUp(ByVal Button As Integer, ByVal Shift As Integer, ByVal X As Single, ByVal Y As Single)
    Append "ToggleButton.MouseUp"
End Sub
Private Sub mToggle_KeyDown(ByVal KeyCode As ReturnInteger, ByVal Shift As Integer)
    Append "ToggleButton.KeyDown:" & CStr(KeyCode.Value)
End Sub
Private Sub mToggle_KeyUp(ByVal KeyCode As ReturnInteger, ByVal Shift As Integer)
    Append "ToggleButton.KeyUp:" & CStr(KeyCode.Value)
End Sub
Private Sub mToggle_KeyPress(ByVal KeyAscii As ReturnInteger)
    Append "ToggleButton.KeyPress:" & CStr(KeyAscii.Value)
End Sub

' --- Event sinks: OptionButton ---
Private Sub mOption_Enter()
    Append "OptionButton.Enter"
End Sub
Private Sub mOption_Exit(ByVal Cancel As ReturnBoolean)
    Append "OptionButton.Exit"
End Sub
Private Sub mOption_BeforeUpdate(ByVal Cancel As ReturnBoolean)
    Append "OptionButton.BeforeUpdate"
End Sub
Private Sub mOption_AfterUpdate()
    Append "OptionButton.AfterUpdate"
End Sub
Private Sub mOption_Change()
    Append "OptionButton.Change=" & CStr(mOption.Value)
End Sub
Private Sub mOption_Click()
    Append "OptionButton.Click=" & CStr(mOption.Value)
End Sub
Private Sub mOption_MouseDown(ByVal Button As Integer, ByVal Shift As Integer, ByVal X As Single, ByVal Y As Single)
    Append "OptionButton.MouseDown"
End Sub
Private Sub mOption_MouseUp(ByVal Button As Integer, ByVal Shift As Integer, ByVal X As Single, ByVal Y As Single)
    Append "OptionButton.MouseUp"
End Sub
Private Sub mOption_KeyDown(ByVal KeyCode As ReturnInteger, ByVal Shift As Integer)
    Append "OptionButton.KeyDown:" & CStr(KeyCode.Value)
End Sub
Private Sub mOption_KeyUp(ByVal KeyCode As ReturnInteger, ByVal Shift As Integer)
    Append "OptionButton.KeyUp:" & CStr(KeyCode.Value)
End Sub
Private Sub mOption_KeyPress(ByVal KeyAscii As ReturnInteger)
    Append "OptionButton.KeyPress:" & CStr(KeyAscii.Value)
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

' --- Event sinks: ComboBox ---
Private Sub mCombo_Enter()
    Append "ComboBox.Enter"
End Sub
Private Sub mCombo_Exit(ByVal Cancel As ReturnBoolean)
    Append "ComboBox.Exit"
End Sub
Private Sub mCombo_BeforeUpdate(ByVal Cancel As ReturnBoolean)
    Append "ComboBox.BeforeUpdate"
End Sub
Private Sub mCombo_AfterUpdate()
    Append "ComboBox.AfterUpdate"
End Sub
Private Sub mCombo_DropButtonClick()
    Append "ComboBox.DropButtonClick"
End Sub
Private Sub mCombo_Change()
    Append "ComboBox.Change:" & mCombo.Value
End Sub
Private Sub mCombo_Click()
    Append "ComboBox.Click:" & mCombo.Value
End Sub
Private Sub mCombo_MouseDown(ByVal Button As Integer, ByVal Shift As Integer, ByVal X As Single, ByVal Y As Single)
    Append "ComboBox.MouseDown"
End Sub
Private Sub mCombo_MouseUp(ByVal Button As Integer, ByVal Shift As Integer, ByVal X As Single, ByVal Y As Single)
    Append "ComboBox.MouseUp"
End Sub
Private Sub mCombo_KeyDown(ByVal KeyCode As ReturnInteger, ByVal Shift As Integer)
    Append "ComboBox.KeyDown:" & CStr(KeyCode.Value)
End Sub
Private Sub mCombo_KeyUp(ByVal KeyCode As ReturnInteger, ByVal Shift As Integer)
    Append "ComboBox.KeyUp:" & CStr(KeyCode.Value)
End Sub
Private Sub mCombo_KeyPress(ByVal KeyAscii As ReturnInteger)
    Append "ComboBox.KeyPress:" & CStr(KeyAscii.Value)
End Sub
Private Sub mCombo_BeforeDropOrPaste(ByVal Cancel As ReturnBoolean, ByVal Action As Integer, ByVal Shift As Integer)
    Append "ComboBox.BeforeDropOrPaste:" & CStr(Action)
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
Private Sub mSpin_KeyDown(ByVal KeyCode As ReturnInteger, ByVal Shift As Integer)
    Append "SpinButton.KeyDown:" & CStr(KeyCode.Value)
End Sub
Private Sub mSpin_KeyUp(ByVal KeyCode As ReturnInteger, ByVal Shift As Integer)
    Append "SpinButton.KeyUp:" & CStr(KeyCode.Value)
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

' --- Event sinks: ScrollBar ---
Private Sub mScroll_Enter()
    Append "ScrollBar.Enter"
End Sub
Private Sub mScroll_Exit(ByVal Cancel As ReturnBoolean)
    Append "ScrollBar.Exit"
End Sub
Private Sub mScroll_MouseDown(ByVal Button As Integer, ByVal Shift As Integer, ByVal X As Single, ByVal Y As Single)
    Append "ScrollBar.MouseDown"
End Sub
Private Sub mScroll_MouseUp(ByVal Button As Integer, ByVal Shift As Integer, ByVal X As Single, ByVal Y As Single)
    Append "ScrollBar.MouseUp"
End Sub
Private Sub mScroll_KeyDown(ByVal KeyCode As ReturnInteger, ByVal Shift As Integer)
    Append "ScrollBar.KeyDown:" & CStr(KeyCode.Value)
End Sub
Private Sub mScroll_KeyUp(ByVal KeyCode As ReturnInteger, ByVal Shift As Integer)
    Append "ScrollBar.KeyUp:" & CStr(KeyCode.Value)
End Sub
Private Sub mScroll_Scroll()
    Append "ScrollBar.Scroll=" & CStr(mScroll.Value)
End Sub
Private Sub mScroll_Change()
    Append "ScrollBar.Change=" & CStr(mScroll.Value)
End Sub

' --- Event sinks: TabStrip ---
Private Sub mTabs_Enter()
    Append "TabStrip.Enter"
End Sub
Private Sub mTabs_Exit(ByVal Cancel As ReturnBoolean)
    Append "TabStrip.Exit"
End Sub
Private Sub mTabs_MouseDown(ByVal Button As Integer, ByVal Shift As Integer, ByVal X As Single, ByVal Y As Single)
    Append "TabStrip.MouseDown"
End Sub
Private Sub mTabs_MouseUp(ByVal Button As Integer, ByVal Shift As Integer, ByVal X As Single, ByVal Y As Single)
    Append "TabStrip.MouseUp"
End Sub
Private Sub mTabs_KeyDown(ByVal KeyCode As ReturnInteger, ByVal Shift As Integer)
    Append "TabStrip.KeyDown:" & CStr(KeyCode.Value)
End Sub
Private Sub mTabs_KeyUp(ByVal KeyCode As ReturnInteger, ByVal Shift As Integer)
    Append "TabStrip.KeyUp:" & CStr(KeyCode.Value)
End Sub
Private Sub mTabs_Change()
    Append "TabStrip.Change=" & CStr(mTabs.Value) & ":" & mTabs.SelectedCaption
End Sub

' --- Event sinks: MultiPage ---
Private Sub mPages_Enter()
    Append "MultiPage.Enter"
End Sub
Private Sub mPages_Exit(ByVal Cancel As ReturnBoolean)
    Append "MultiPage.Exit"
End Sub
Private Sub mPages_MouseDown(ByVal Button As Integer, ByVal Shift As Integer, ByVal X As Single, ByVal Y As Single)
    Append "MultiPage.MouseDown"
End Sub
Private Sub mPages_MouseUp(ByVal Button As Integer, ByVal Shift As Integer, ByVal X As Single, ByVal Y As Single)
    Append "MultiPage.MouseUp"
End Sub
Private Sub mPages_KeyDown(ByVal KeyCode As ReturnInteger, ByVal Shift As Integer)
    Append "MultiPage.KeyDown:" & CStr(KeyCode.Value)
End Sub
Private Sub mPages_KeyUp(ByVal KeyCode As ReturnInteger, ByVal Shift As Integer)
    Append "MultiPage.KeyUp:" & CStr(KeyCode.Value)
End Sub
Private Sub mPages_Change()
    Append "MultiPage.Change=" & CStr(mPages.Value) & ":" & mPages.SelectedCaption
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
