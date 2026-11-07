VERSION 5.00
Begin {C62A69F0-16DC-11CE-9E98-00AA00574A4F} PlannerForm 
   Caption         =   "CalcForms planner"
   ClientHeight    =   4215
   ClientLeft      =   120
   ClientTop       =   465
   ClientWidth     =   7560
   OleObjectBlob   =   "PlannerForm-qualified.frx":0000
   StartUpPosition =   1  'CenterOwner
End
Attribute VB_Name = "PlannerForm"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = False
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
Option Explicit
Private WithEvents DayPicker As MSForms.SpinButton
Attribute DayPicker.VB_VarHelpID = -1
Private WithEvents HourPicker As MSForms.ScrollBar
Attribute HourPicker.VB_VarHelpID = -1
Private WithEvents AllDay As MSForms.ToggleButton
Attribute AllDay.VB_VarHelpID = -1
Private WithEvents ViewTabs As MSForms.TabStrip
Attribute ViewTabs.VB_VarHelpID = -1
Private mReady As Boolean
Private mTrace As String
Private mFailure As String

Private Sub UserForm_Initialize()
    On Error GoTo Failed
    mReady = False
    mTrace = "Initialize"
    Set DayPicker = Me.Controls.Add("Forms.SpinButton.1", "DayPicker")
    DayPicker.Left = 12
    DayPicker.Top = 30
    DayPicker.Width = 24
    DayPicker.Height = 36
    DayPicker.Min = 0
    DayPicker.Max = 30
    DayPicker.Value = 1
    Set HourPicker = Me.Controls.Add("Forms.ScrollBar.1", "HourPicker")
    HourPicker.Left = 60
    HourPicker.Top = 30
    HourPicker.Width = 180
    HourPicker.Height = 18
    HourPicker.Min = 0
    HourPicker.Max = 23
    HourPicker.Value = 9
    Set AllDay = Me.Controls.Add("Forms.ToggleButton.1", "AllDay")
    AllDay.Left = 264
    AllDay.Top = 30
    AllDay.Width = 90
    AllDay.Height = 24
    AllDay.Caption = "All day"
    Set ViewTabs = Me.Controls.Add("Forms.TabStrip.1", "ViewTabs")
    ViewTabs.Left = 12
    ViewTabs.Top = 90
    ViewTabs.Width = 342
    ViewTabs.Height = 48
    ViewTabs.Tabs.Clear
    Dim T As Object
    Set T = ViewTabs.Tabs.Add("Day")
    T.Caption = "Day"
    Set T = ViewTabs.Tabs.Add("Week")
    T.Caption = "Week"
    ViewTabs.Value = 0
    mReady = True
    RefreshSummary
    Exit Sub
Failed:
    mFailure = "initialize:" & CStr(Err.Number) & ":" & Err.Description
End Sub

Private Sub RefreshSummary()
    If Not mReady Then Exit Sub
    Summary.Caption = "Day " & CStr(DayPicker.Value) & " at " & CStr(HourPicker.Value)
    If AllDay.Value Then Summary.Caption = "Day " & CStr(DayPicker.Value) & " all day"
    If ViewTabs.Value = 1 Then Summary.Caption = "Week: " & Summary.Caption
End Sub

Private Sub DayPicker_Change()
    If Not mReady Then Exit Sub
    mTrace = mTrace & "|day=" & CStr(DayPicker.Value)
    RefreshSummary
End Sub
Private Sub DayPicker_SpinUp()
    If mReady Then mTrace = mTrace & "|spin-up=" & CStr(DayPicker.Value)
End Sub
Private Sub DayPicker_SpinDown()
    If mReady Then mTrace = mTrace & "|spin-down=" & CStr(DayPicker.Value)
End Sub
Private Sub HourPicker_Change()
    If Not mReady Then Exit Sub
    mTrace = mTrace & "|hour=" & CStr(HourPicker.Value)
    RefreshSummary
End Sub
Private Sub HourPicker_Scroll()
    If mReady Then mTrace = mTrace & "|scroll=" & CStr(HourPicker.Value)
End Sub
Private Sub AllDay_Change()
    If mReady Then mTrace = mTrace & "|all-day-change=" & CStr(AllDay.Value)
End Sub
Private Sub AllDay_Click()
    If Not mReady Then Exit Sub
    mTrace = mTrace & "|all-day-click=" & CStr(AllDay.Value)
    RefreshSummary
End Sub
Private Sub ViewTabs_Change()
    If Not mReady Then Exit Sub
    mTrace = mTrace & "|view=" & CStr(ViewTabs.Value)
    RefreshSummary
End Sub
Private Sub CloseButton_Click()
    mTrace = mTrace & "|close"
    Me.Hide
End Sub

Public Function State() As String
    On Error GoTo Failed
    If Len(mFailure) > 0 Then Err.Raise 5, "Planner", mFailure
    State = "day=" & CStr(DayPicker.Value) & ";hour=" & CStr(HourPicker.Value) & ";all-day=" & CStr(AllDay.Value) & ";view=" & CStr(ViewTabs.Value) & ";summary=" & Summary.Caption & ";visible=" & CStr(Me.Visible)
    Exit Function
Failed:
    State = "CALCFORMS_NATIVE_ERROR:" & CStr(Err.Number) & ":" & Err.Description
End Function
Public Function Trace() As String
    Trace = mTrace
End Function

