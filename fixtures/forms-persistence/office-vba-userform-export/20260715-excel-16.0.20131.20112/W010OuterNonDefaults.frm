VERSION 5.00
Begin {C62A69F0-16DC-11CE-9E98-00AA00574A4F} W010OuterNonDefaults 
   Caption         =   "Café ""quoted"""
   ClientHeight    =   3855
   ClientLeft      =   795
   ClientTop       =   1365
   ClientWidth     =   6195
   Enabled         =   0   'False
   HelpContextID   =   42
   OleObjectBlob   =   "W010OuterNonDefaults.frx":0000
   ShowModal       =   0   'False
   Tag             =   "tag;one=1"
   WhatsThisButton =   -1  'True
   WhatsThisHelp   =   -1  'True
End
Attribute VB_Name = "W010OuterNonDefaults"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = False
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
Option Explicit

Public Function QuoteProbe() As String
    QuoteProbe = "code = ""value"""
End Function

Private Sub AssignmentShapedCode()
    Caption = "this is code, not designer metadata"
End Sub

