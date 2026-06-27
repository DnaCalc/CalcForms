Option Explicit

' W006 CheckBox Click-vs-Change oracle UserForm code-behind.
'
' ToggleCheck fills the form, so a single click at the window centre toggles it.
' Both handlers log their sequence AND the control's .Value at handler entry, so
' the export shows (a) whether Change fires before or after Click and (b) whether
' .Value is already toggled when each handler runs. That settles the MSForms
' ordering: value-change-first (Change before Click, .Value already toggled in
' Click) vs click-first. No OxForms runtime behaviour is implied.

Private Sub UserForm_Initialize()
    W006CheckBoxLog Me.Name, "ToggleCheck", "Initialize", CStr(ToggleCheck.Value), "form initialize"
End Sub

Private Sub ToggleCheck_Click()
    W006CheckBoxLog Me.Name, "ToggleCheck", "Click", CStr(ToggleCheck.Value), "Click handler; .Value read at handler entry"
End Sub

Private Sub ToggleCheck_Change()
    W006CheckBoxLog Me.Name, "ToggleCheck", "Change", CStr(ToggleCheck.Value), "Change handler; .Value read at handler entry"
End Sub
