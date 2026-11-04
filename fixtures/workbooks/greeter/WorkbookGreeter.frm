VERSION 5.00
Begin {C62A69F0-16DC-11CE-9E98-00AA00574A4F} WorkbookGreeter 
   Caption         =   "CalcForms workbook greeter"
   ClientHeight    =   2610
   ClientLeft      =   120
   ClientTop       =   465
   ClientWidth     =   5760
   OleObjectBlob   =   "WorkbookGreeter.frx":0000
   StartUpPosition =   1  'CenterOwner
End
Attribute VB_Name = "WorkbookGreeter"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = False
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
Option Explicit
Private mLog As String

Private Sub UserForm_Initialize()
    mLog = "Initialize"
End Sub

Private Sub InputName_Change()
    mLog = mLog & "|Change:" & InputName.Text
End Sub

Private Sub Greet_Click()
    Output.Caption = "Hello, " & InputName.Text
    If Loud.Value Then Output.Caption = UCase$(Output.Caption)
    mLog = mLog & "|Click:" & Output.Caption
End Sub

Private Sub Loud_Click()
    mLog = mLog & "|Check:" & CStr(Loud.Value)
End Sub

Public Function State() As String
    State = mLog & ";text=" & InputName.Text & ";caption=" & Output.Caption & ";loud=" & CStr(Loud.Value)
End Function

