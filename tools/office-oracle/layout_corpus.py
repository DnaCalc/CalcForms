"""Authored layout fixtures; only data construction lives in this test tool.

Excel uses native MSForms controls. CalcForms uses its production VBA controls
and retained Scene. This does not grant Office binary-persistence or full API
compatibility credit for the authored controls.
"""
from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CORPUS = ROOT / 'fixtures/office-oracle/excel-msforms/layout-corpus.v1.json'
KINDS = {'Label', 'TextBox', 'CommandButton', 'CheckBox', 'OptionButton',
         'ToggleButton', 'ListBox', 'ComboBox', 'Frame', 'Image', 'SpinButton',
         'ScrollBar', 'TabStrip', 'MultiPage'}
TEXT_KINDS = KINDS - {'Image', 'SpinButton', 'ScrollBar'}



def walk(controls):
    for control in controls:
        yield control
        yield from walk(control.get('children', []))


def load_corpus():
    data = json.loads(CORPUS.read_text(encoding='utf-8'))
    if data['schema'] != 'calcforms.layout_corpus.v1':
        raise ValueError('Unknown layout corpus schema')
    kinds = set()
    for form in data['forms']:
        names = set()
        for control in walk(form['controls']):
            if control['name'].lower() in names or not control['name'].isascii() or not control['name'].isidentifier():
                raise ValueError('Duplicate/invalid authored control name')
            names.add(control['name'].lower())
            if control['kind'] not in KINDS:
                raise ValueError('Unknown authored control')
            kinds.add(control['kind'])
    if kinds != KINDS:
        raise ValueError('The authored corpus must cover every intrinsic control kind')
    return data


def literal(text):
    return '"' + text.replace('"', '""') + '"'


def boolean(value):
    return 'True' if value else 'False'


def runtime_source(form, corpus):
    """Build the real VBA object model through Controls.Add, not a Rust replica."""
    controls = list(walk(form['controls']))
    declarations = []
    build = ['    Set CalcFormsHostForm = New UserForm',
             '    CalcFormsHostForm.Name = ' + literal(form['name']),
             '    CalcFormsHostForm.Caption = ' + literal(form['caption']),
             f'    CalcFormsHostForm.Width = {form["width"]}',
             f'    CalcFormsHostForm.Height = {form["height"]}']
    def add(children, parent):
        for index, c in enumerate(children):
            name, kind = c['name'], c['kind']
            cls = 'OptionButtonControl' if kind == 'OptionButton' else kind
            declarations.append(f'Public {name} As {cls}')
            build.append(f'    Set {name} = {parent}.Controls.Add("Forms.{kind}.1", {literal(name)})')
            for property in ['Left', 'Top', 'Width', 'Height']:
                build.append(f'    {name}.{property} = {c[property.lower()]}')
            build.extend([f'    {name}.Core.TabIndex = {index}',
                          f'    {name}.Core.FontSize = {corpus["font_size"]}',
                          f'    {name}.Enabled = {boolean(c.get("enabled", True))}'])
            if 'caption' in c:
                build.append(f'    {name}.Caption = {literal(c["caption"])}')
            if 'text' in c:
                build.append(f'    {name}.Text = {literal(c["text"])}')
            if 'value' in c:
                build.append(f'    {name}.Value = {boolean(c["value"])}')
            if c.get('default'):
                build.append(f'    {name}.Default = True')
            for item in c.get('items', []):
                build.append(f'    {name}.AddItem {literal(item)}')
            if c.get('items'):
                build.append(f'    {name}.ListIndex = 1')
            for item in c.get('tabs', []):
                build.append(f'    {name}.Tabs.Add {literal(item)}')
            for item in c.get('pages', []):
                build.append(f'    {name}.Pages.Add {literal(item)}')
            add(c.get('children', []), name)
    add(form['controls'], 'CalcFormsHostForm')
    build += ['    Set CalcFormsHostReducer = New OxReducer',
              '    CalcFormsHostReducer.Init CalcFormsHostForm']
    host = (ROOT / 'vba/calcforms/runtime/WorkbookFormHost.vba').read_text(encoding='utf-8')
    host = host.replace('%BUILD%', '\n'.join(build))
    for token in ['INITIALIZE', 'ACTIVATE', 'DEACTIVATE', 'TERMINATE', 'QUERY_CLOSE']:
        host = host.replace('%' + token + '%', '')
    input_control = next((c for c in controls if c['kind'] == 'TextBox'), None)
    host = host.replace('%INPUT%', input_control['name'] + '.Text' if input_control else '""')
    facts = ['Public Function LayoutFacts() As String', '    LayoutFacts = ""']
    def report(children, prefix=''):
        for c in children:
            name = c['name']
            fields = [literal(prefix) + ' & ' + name + '.Name', literal(c['kind'])]
            fields += [f'CStr({name}.{p})' for p in ['Left', 'Top', 'Width', 'Height']]
            fields += [f'CStr({name}.Core.{p})' for p in ['NodeId', 'PaintLeft', 'PaintTop', 'FontSize', 'TabIndex']]
            facts.append('    LayoutFacts = LayoutFacts & ' + ' & ";" & '.join(fields) + ' & vbLf')
            report(c.get('children', []), prefix + name + '.')
    report(form['controls'])
    facts.append('End Function')
    return 'Option Explicit\n' + '\n'.join(declarations) + '\n' + host + '\n' + '\n'.join(facts) + '\n'


def author_excel(excel, directory, corpus):
    """Create all native forms in the already-owned Excel; never launch Office."""
    book = excel.Workbooks.Add()
    for form in corpus['forms']:
        component = book.VBProject.VBComponents.Add(3)
        component.Name = form['name']
        component.Properties.Item('Caption').Value = form['caption']
        # LayoutShow below corrects these to the requested exact client size.
        component.Properties.Item('Width').Value = form['width'] + 12
        component.Properties.Item('Height').Value = form['height'] + 30
        initialize = ['Private Sub UserForm_Initialize()']
        def add(children, parent):
            for c in children:
                kind, name = c['kind'], c['name']
                control = parent.Controls.Add('Forms.' + kind + '.1', name, True)
                for property in ['Left', 'Top', 'Width', 'Height']:
                    setattr(control, property, c[property.lower()])
                control.Enabled = c.get('enabled', True)
                if kind in TEXT_KINDS:
                    control.Font.Name = corpus['font']
                    control.Font.Size = corpus['font_size']
                if 'caption' in c:
                    control.Caption = c['caption']
                if 'text' in c:
                    control.Text = c['text']
                if 'value' in c:
                    control.Value = c['value']
                if c.get('default'):
                    control.Default = True
                for item in c.get('items', []):
                    initialize.append(f'    {name}.AddItem {literal(item)}')
                if c.get('items'):
                    initialize.append(f'    {name}.ListIndex = 1')
                for index, caption in enumerate(c.get('tabs', [])):
                    control.Tabs.Item(index).Caption = caption
                for index, caption in enumerate(c.get('pages', [])):
                    control.Pages.Item(index).Caption = caption
                add(c.get('children', []), control)
        add(form['controls'], component.Designer)
        initialize.append('End Sub')
        component.CodeModule.AddFromString('Option Explicit\n' + '\n'.join(initialize))
        component.Export(str(directory / (form['name'] + '.frm')))
        (directory / (form['name'] + '.cls')).write_text(runtime_source(form, corpus), encoding='utf-8', newline='\n')
    module = book.VBProject.VBComponents.Add(1)
    module.Name = 'LayoutEntry'
    cases = '\n'.join('        Case ' + literal(f['name']) + ': Set LayoutForm = ' + f['name'] for f in corpus['forms'])
    module.CodeModule.AddFromString('''Option Explicit
Private LayoutForm As Object
Public Sub LayoutShow(ByVal Name As String, ByVal W As Single, ByVal H As Single, ByVal Zoom As Long)
    If Not LayoutForm Is Nothing Then
        Unload LayoutForm
        Set LayoutForm = Nothing
    End If
    Select Case Name
''' + cases + '''
    End Select
    LayoutForm.Width = LayoutForm.Width + W - LayoutForm.InsideWidth
    LayoutForm.Height = LayoutForm.Height + H - LayoutForm.InsideHeight
    LayoutForm.Zoom = Zoom
    LayoutForm.Width = LayoutForm.Width + W * (Zoom / 100 - 1)
    LayoutForm.Height = LayoutForm.Height + H * (Zoom / 100 - 1)
    LayoutForm.Show vbModeless
    LayoutForm.Repaint
End Sub
Public Function LayoutFacts() As String
    Dim S As String
    S = CStr(LayoutForm.InsideWidth) & ";" & CStr(LayoutForm.InsideHeight) & ";" & CStr(LayoutForm.Zoom)
    LayoutFacts = S & vbLf & ControlFacts(LayoutForm, "")
End Function
Public Sub LayoutHide()
    If Not LayoutForm Is Nothing Then
        Unload LayoutForm
        Set LayoutForm = Nothing
    End If
End Sub
Public Function LayoutPaintFacts() As String
    On Error GoTo Failed
    Dim C As Object, P As Object, S As String
    For Each C In LayoutForm.Controls
        If TypeName(C) = "MultiPage" And C.Parent Is LayoutForm Then
            Set P = C.Pages(C.Value)
            If P.Controls.Count = 0 Then
                S = S & C.Name & ";" & CStr(C.BackColor) & ";" & CStr(C.Left + C.Width / 2) & ";" & CStr(C.Top + C.Height / 2) & vbLf
            End If
        End If
    Next
    LayoutPaintFacts = S
    Exit Function
Failed:
    LayoutPaintFacts = "CALCFORMS_NATIVE_ERROR:" & CStr(Err.Number) & ":" & Err.Description
End Function
Private Function ControlFacts(ByVal Owner As Object, ByVal Prefix As String) As String
    Dim C As Object, S As String
    For Each C In Owner.Controls
        If C.Parent Is Owner Then
        S = S & Prefix & C.Name & ";" & TypeName(C) & ";" & CStr(C.Left) & ";" & CStr(C.Top) & ";" & CStr(C.Width) & ";" & CStr(C.Height)
        If TypeName(C) <> "Image" And TypeName(C) <> "SpinButton" And TypeName(C) <> "ScrollBar" Then
            S = S & ";" & C.Font.Name & ";" & CStr(C.Font.Size) & ";" & CStr(C.TabIndex)
        End If
        S = S & vbLf
        If TypeName(C) = "Frame" Then S = S & ControlFacts(C, Prefix & C.Name & ".")
        End If
    Next
    ControlFacts = S
End Function
''')
    path = directory / 'layout-corpus.xlsm'
    book.SaveAs(str(path), 52)
    return book
