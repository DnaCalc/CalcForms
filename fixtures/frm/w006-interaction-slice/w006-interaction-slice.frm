VERSION 5.00
Begin {C62A69F0-16DC-11CE-9E98-00AA00574A4F} OxFormsW006InteractionForm
   Caption         =   "OxForms W006 Interaction Slice"
   ClientHeight    =   3600
   ClientWidth     =   4800
   StartUpPosition =   2
   Begin MSForms.Label OracleProbeLabel
      Caption         =   "Probe Label"
      Left            =   480
      Top             =   480
      Width           =   1920
      Height          =   960
      Enabled         =   -1
      Visible         =   -1
      BackColor       =   12611616
      ForeColor       =   16777215
      BorderStyle     =   1
      TabStop         =   0
   End
   Begin MSForms.TextBox OracleTextBox
      Text            =   "seed"
      Left            =   2640
      Top             =   480
      Width           =   1440
      Height          =   480
      TabIndex        =   0
      TabStop         =   -1
      Enabled         =   -1
      Visible         =   -1
      BorderStyle     =   1
      MultiLine       =   0
   End
   Begin MSForms.CommandButton OracleDefaultButton
      Caption         =   "&OK"
      Left            =   2640
      Top             =   1200
      Width           =   1440
      Height          =   480
      TabIndex        =   1
      TabStop         =   -1
      Default         =   -1
      Cancel          =   0
      TakeFocusOnClick=   -1
   End
   Begin MSForms.CommandButton OracleCancelButton
      Caption         =   "&Cancel"
      Left            =   2640
      Top             =   1920
      Width           =   1440
      Height          =   480
      TabIndex        =   2
      TabStop         =   -1
      Default         =   0
      Cancel          =   -1
      TakeFocusOnClick=   -1
   End
End
Attribute VB_Name = "OxFormsW006InteractionForm"
