VERSION 5.00
Begin {C62A69F0-16DC-11CE-9E98-00AA00574A4F} W009MaterializationForm
   Caption         =   "W009 Materialized Form"
   ClientHeight    =   3800
   ClientWidth     =   5200
   StartUpPosition =   2
   Begin MSForms.Label TitleLabel
      Caption         =   "Materialized label"
      Left            =   240
      Top             =   200
      Width           =   3600
      Height          =   360
      Enabled         =   -1
      Visible         =   -1
      BackColor       =   12611616
      ForeColor       =   16777215
      BorderStyle     =   1
      TabStop         =   0
   End
   Begin MSForms.TextBox InputField
      Value           =   "seed"
      Left            =   240
      Top             =   760
      Width           =   2200
      Height          =   420
      TabIndex        =   0
      TabStop         =   -1
      Enabled         =   -1
      Visible         =   -1
      BorderStyle     =   1
   End
   Begin MSForms.CommandButton DefaultButton
      Caption         =   "&OK"
      Left            =   2700
      Top             =   760
      Width           =   900
      Height          =   420
      TabIndex        =   1
      TabStop         =   -1
      Default         =   -1
      Cancel          =   0
   End
   Begin MSForms.CommandButton CancelButton
      Caption         =   "Cancel"
      Left            =   3720
      Top             =   760
      Width           =   960
      Height          =   420
      TabIndex        =   2
      TabStop         =   -1
      Default         =   0
      Cancel          =   -1
   End
   Begin MSForms.CheckBox AcceptCheck
      Caption         =   "Accept"
      Value           =   -1
      Left            =   240
      Top             =   1400
      Width           =   2200
      Height          =   420
      TabIndex        =   3
      TabStop         =   -1
      Enabled         =   -1
      Visible         =   -1
      BackColor       =   16777215
      ForeColor       =   0
   End
   Begin MSForms.ToggleButton ModeToggle
      Caption         =   "Mode"
      Value           =   -1
      Left            =   2700
      Top             =   1400
      Width           =   1200
      Height          =   420
      TabIndex        =   4
      TabStop         =   -1
      Enabled         =   -1
      Visible         =   -1
   End
   Begin MSForms.OptionButton ModeOption
      Caption         =   "Option"
      GroupName       =   "Mode"
      Value           =   -1
      Left            =   2700
      Top             =   1900
      Width           =   1200
      Height          =   420
      TabIndex        =   5
      TabStop         =   -1
      Enabled         =   -1
      Visible         =   -1
   End
   Begin MSForms.ListBox ChoicesList
      Left            =   240
      Top             =   2440
      Width           =   2200
      Height          =   840
      TabIndex        =   6
      TabStop         =   -1
      Enabled         =   -1
      Visible         =   -1
      MultiSelect     =   2
      ColumnCount     =   2
      BoundColumn     =   2
   End
   Begin MSForms.Image LogoImage
      Picture         =   "w009-representative.frx":0000
      Left            =   3200
      Top             =   2440
      Width           =   640
      Height          =   480
      Enabled         =   -1
      Visible         =   -1
      PictureSizeMode =   3
   End
   Begin MSForms.ComboBox SizeCombo
      Value           =   "Medium"
      Left            =   2700
      Top             =   3200
      Width           =   1600
      Height          =   420
      TabIndex        =   7
      TabStop         =   -1
      Enabled         =   -1
      Visible         =   -1
   End
End
Attribute VB_Name = "W009MaterializationForm"
