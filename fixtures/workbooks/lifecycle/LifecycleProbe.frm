VERSION 5.00
Begin {C62A69F0-16DC-11CE-9E98-00AA00574A4F} LifecycleProbe 
   Caption         =   "CalcForms lifetime probe"
   ClientHeight    =   2010
   ClientLeft      =   120
   ClientTop       =   465
   ClientWidth     =   4560
   OleObjectBlob   =   "LifecycleProbe.frx":0000
   StartUpPosition =   1  'CenterOwner
End
Attribute VB_Name = "LifecycleProbe"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = False
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
Option Explicit
Private mGeneration As Long
Private mVeto As Boolean
Private Sub UserForm_Initialize()
    mGeneration = NextGeneration()
    AppendTrace "Initialize:" & CStr(mGeneration)
End Sub
Private Sub UserForm_Activate()
    AppendTrace "Activate:" & CStr(mGeneration)
End Sub
Private Sub UserForm_Deactivate()
    AppendTrace "Deactivate:" & CStr(mGeneration)
End Sub
Private Sub UserForm_QueryClose(Cancel As Integer, CloseMode As Integer)
    AppendTrace "QueryClose:" & CStr(mGeneration) & ":" & CStr(CloseMode)
    If mVeto Then
        Cancel = 1
        mVeto = False
    End If
End Sub
Private Sub UserForm_Terminate()
    AppendTrace "Terminate:" & CStr(mGeneration)
End Sub
Private Sub HideButton_Click()
    Me.Hide
End Sub
Public Property Get Generation() As Long
    Generation = mGeneration
End Property
Public Sub VetoNextClose()
    mVeto = True
End Sub
Public Function State() As String
    State = CStr(mGeneration) & ":" & InputName.Text
End Function

