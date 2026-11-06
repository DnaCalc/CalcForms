Option Explicit
Private WithEvents TeamChoice As MSForms.ComboBox
Private WithEvents Products As MSForms.ListBox
Private WithEvents Sections As MSForms.MultiPage
Private ShippingFrame As MSForms.Frame
Private PaymentFrame As MSForms.Frame
Private StandardShipping As Object
Private PriorityShipping As Object
Private InvoicePayment As Object
Private PrepaidPayment As Object
Private Notes As MSForms.TextBox
Private mTrace As String
Private mFailure As String
Private mSaved As Long

Private Sub UserForm_Initialize()
    On Error GoTo Failed
    mTrace = "Initialize"
    mSaved = 0
    Dim C As Object, P As Object
    Set C = Me.Controls.Add("Forms.Label.1", "TeamLabel")
    Place C, 12, 50, 186, 12
    C.Caption = "Team"
    Set TeamChoice = Me.Controls.Add("Forms.ComboBox.1", "TeamChoice")
    Place TeamChoice, 12, 66, 186, 21
    TeamChoice.AddItem "Sales"
    TeamChoice.AddItem "Engineering"
    TeamChoice.AddItem "Support"
    TeamChoice.ListIndex = 0
    Set C = Me.Controls.Add("Forms.Label.1", "ProductsLabel")
    Place C, 216, 4, 186, 12
    C.Caption = "Product"
    Set Products = Me.Controls.Add("Forms.ListBox.1", "Products")
    Place Products, 216, 18, 186, 72
    Products.AddItem "Bolt"
    Products.AddItem "Nut"
    Products.AddItem "Washer"
    Products.ListIndex = 0
    Set ShippingFrame = Me.Controls.Add("Forms.Frame.1", "ShippingFrame")
    Place ShippingFrame, 12, 108, 186, 84
    ShippingFrame.Caption = "Shipping"
    Set StandardShipping = ShippingFrame.Controls.Add("Forms.OptionButton.1", "StandardShipping")
    Place StandardShipping, 12, 18, 150, 18
    StandardShipping.Caption = "Standard"
    StandardShipping.GroupName = "Shipping"
    Set PriorityShipping = ShippingFrame.Controls.Add("Forms.OptionButton.1", "PriorityShipping")
    Place PriorityShipping, 12, 42, 150, 18
    PriorityShipping.Caption = "Priority"
    PriorityShipping.GroupName = "Shipping"
    StandardShipping.Value = True
    Set PaymentFrame = Me.Controls.Add("Forms.Frame.1", "PaymentFrame")
    Place PaymentFrame, 216, 108, 186, 84
    PaymentFrame.Caption = "Payment"
    Set InvoicePayment = PaymentFrame.Controls.Add("Forms.OptionButton.1", "InvoicePayment")
    Place InvoicePayment, 12, 18, 150, 18
    InvoicePayment.Caption = "Invoice"
    InvoicePayment.GroupName = "Payment"
    Set PrepaidPayment = PaymentFrame.Controls.Add("Forms.OptionButton.1", "PrepaidPayment")
    Place PrepaidPayment, 12, 42, 150, 18
    PrepaidPayment.Caption = "Prepaid"
    PrepaidPayment.GroupName = "Payment"
    InvoicePayment.Value = True
    Set Sections = Me.Controls.Add("Forms.MultiPage.1", "Sections")
    Place Sections, 12, 204, 390, 84
    Do While Sections.Pages.Count < 2
        Set P = Sections.Pages.Add("Page" & CStr(Sections.Pages.Count + 1))
    Loop
    Sections.Pages.Item(0).Caption = "Delivery"
    Sections.Pages.Item(1).Caption = "Review"
    Set Notes = Sections.Pages.Item(0).Controls.Add("Forms.TextBox.1", "Notes")
    Place Notes, 12, 12, 348, 24
    Notes.Text = "Leave at reception"
    Set C = Sections.Pages.Item(1).Controls.Add("Forms.Label.1", "ReviewPrompt")
    Place C, 12, 12, 348, 18
    C.Caption = "Review the order before saving."
    Sections.Value = 0
    StatusLabel.Caption = "Ready"
    Exit Sub
Failed:
    mFailure = "Initialize:" & CStr(Err.Number) & ":" & Err.Description
End Sub

Private Sub Place(ByVal C As Object, ByVal X As Single, ByVal Y As Single, ByVal W As Single, ByVal H As Single)
    C.Left = X
    C.Top = Y
    C.Width = W
    C.Height = H
End Sub

Private Sub Record(ByVal EventName As String)
    mTrace = mTrace & "|" & EventName
End Sub

Private Sub NameInput_Change()
    On Error GoTo Failed
    Record "Name.Change:" & NameInput.Text
    Exit Sub
Failed:
    mFailure = "Name.Change:" & CStr(Err.Number)
End Sub

Private Sub NameInput_BeforeUpdate(ByVal Cancel As MSForms.ReturnBoolean)
    On Error GoTo Failed
    Record "Name.BeforeUpdate"
    If Len(Trim$(NameInput.Text)) = 0 Then
        Cancel.Value = True
        StatusLabel.Caption = "Name is required"
        Record "Name.Veto"
    End If
    Exit Sub
Failed:
    mFailure = "Name.BeforeUpdate:" & CStr(Err.Number)
End Sub

Private Sub TeamChoice_Change()
    On Error GoTo Failed
    Record "Team.Change:" & TeamChoice.Text
    Exit Sub
Failed:
    mFailure = "Team.Change:" & CStr(Err.Number)
End Sub

Private Sub Products_Change()
    On Error GoTo Failed
    Record "Product.Change:" & Products.Value
    Exit Sub
Failed:
    mFailure = "Product.Change:" & CStr(Err.Number)
End Sub

Private Sub Products_Click()
    On Error GoTo Failed
    Record "Product.Click:" & Products.Value
    Exit Sub
Failed:
    mFailure = "Product.Click:" & CStr(Err.Number)
End Sub

Private Sub Sections_Change()
    On Error GoTo Failed
    Record "Page.Change:" & CStr(Sections.Value)
    Exit Sub
Failed:
    mFailure = "Page.Change:" & CStr(Err.Number)
End Sub

Private Sub SaveButton_Click()
    On Error GoTo Failed
    Record "Save.Click"
    If Len(Trim$(NameInput.Text)) = 0 Then
        StatusLabel.Caption = "Name is required"
        Record "Save.Invalid"
        Exit Sub
    End If
    If TeamChoice.ListIndex < 0 Or Products.ListIndex < 0 Then
        StatusLabel.Caption = "Choose a team and product"
        Record "Save.Invalid"
        Exit Sub
    End If
    mSaved = mSaved + 1
    StatusLabel.Caption = "Saved " & NameInput.Text & ": " & Products.Value
    Record "Save.Valid"
    Exit Sub
Failed:
    mFailure = "Save.Click:" & CStr(Err.Number)
End Sub

Private Sub CancelButton_Click()
    On Error GoTo Failed
    Record "Cancel.Click"
    Me.Hide
    Exit Sub
Failed:
    mFailure = "Cancel.Click:" & CStr(Err.Number)
End Sub

Public Sub SetName(ByVal Value As String)
    NameInput.Text = Value
End Sub

Public Sub SetTeam(ByVal Index As Long)
    TeamChoice.ListIndex = Index
End Sub

Public Sub SetProduct(ByVal Index As Long)
    Products.ListIndex = Index
End Sub

Public Sub ChoosePriority()
    PriorityShipping.Value = True
End Sub

Public Sub ChoosePrepaid()
    PrepaidPayment.Value = True
End Sub

Public Sub SelectPage(ByVal Index As Long)
    Sections.Value = Index
End Sub

Public Function State() As String
    On Error GoTo Failed
    If Len(mFailure) > 0 Then
        State = "CALCFORMS_NATIVE_ERROR:" & mFailure
        Exit Function
    End If
    State = "name=" & NameInput.Text & ";team=" & TeamChoice.Text & ";product=" & Products.Value _
        & ";standard=" & CStr(StandardShipping.Value) & ";priority=" & CStr(PriorityShipping.Value) _
        & ";invoice=" & CStr(InvoicePayment.Value) & ";prepaid=" & CStr(PrepaidPayment.Value) _
        & ";page=" & CStr(Sections.Value) & ";notes=" & Notes.Text & ";saved=" & CStr(mSaved) _
        & ";status=" & StatusLabel.Caption & ";visible=" & CStr(Me.Visible)
    Exit Function
Failed:
    State = "CALCFORMS_NATIVE_ERROR:State:" & CStr(Err.Number) & ":" & Err.Description
End Function

Public Function Trace() As String
    Trace = mTrace
End Function
