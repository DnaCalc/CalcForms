"""Scoped Enter/Escape and overflowing-list observations, shared VBA scenarios."""
from input_probes import runtime_source as input_runtime
from layout_corpus import literal, walk


def shared_source(form):
    controls = list(walk(form['controls']))
    source = []
    for c in controls:
        if c['kind'] == 'CommandButton':
            source.append(f'''Private Sub {c['name']}_Click()
    On Error GoTo Failed
    mParityEvents = mParityEvents & {literal(c['name'] + '.Click|')}
    Exit Sub
Failed:
    mParityFailure = "command-click:" & CStr(Err.Number) & ":" & Err.Description
End Sub''')
    source.append('''Private Function ParityListSnapshot(ByVal C As Object) As String
    On Error GoTo Failed
    Dim S As String, Stage As String
    S = "index=" & CStr(C.ListIndex) & ";count=" & CStr(C.ListCount)
    Stage = "top"
    ParityListSnapshot = S & ";top=" & CStr(C.TopIndex)
    Exit Function
Failed:
    If Stage = "top" Then
        ParityListSnapshot = S & ";top_error=" & CStr(Err.Number)
    Else
        ParityListSnapshot = "CALCFORMS_NATIVE_ERROR:list-state:" & CStr(Err.Number) & ":" & Err.Description
    End If
End Function''')
    prepare = ['Public Function ParityScroll(ByVal Prepare As Boolean) As String',
               '    On Error GoTo Failed', '    Dim I As Long, S As String']
    for c in controls:
        if c['kind'] != 'ListBox':
            continue
        name = c['name']
        prepare += ['    If Prepare Then', '        For I = 1 To 20',
                    f'            {name}.AddItem "Row " & CStr(I)', '        Next', '    End If',
                    f'    S = ParityListSnapshot({name})']
    prepare += ['    ParityScroll = S', '    Exit Function', 'Failed:',
                '    ParityScroll = "CALCFORMS_NATIVE_ERROR:scroll:" & CStr(Err.Number) & ":" & Err.Description', 'End Function']
    return '\n\n'.join([*source, '\n'.join(prepare)]) + '\n'


def runtime_source(source, form, points):
    source = input_runtime(source, form, points) + '\n' + shared_source(form)
    body = ['Public Function ParityKeyboardMeasurements() As String', '    On Error GoTo Failed',
            '    Dim S As String, E As String',
            '    E = CalcFormsHostReducer.DispatchKey("keydown", 9, 0)',
            '    E = CalcFormsHostReducer.DispatchKey("keyup", 9, 0)']
    for point in points:
        name, (x, y) = point['control'], point['point_pt']
        body += [f'    E = CalcFormsHostReducer.Dispatch("mousedown", {x}, {y}, 1, 0)',
                 f'    E = CalcFormsHostReducer.Dispatch("mouseup", {x}, {y}, 1, 0)']
        for metric, step, key in [('enter_default', 'enter', 13), ('escape_cancel', 'escape', 27)]:
            body += ['    mParityEvents = ""', '    mParityFailure = ""',
                     f'    E = CalcFormsHostReducer.DispatchKey("keydown", {key}, 0)',
                     f'    E = CalcFormsHostReducer.DispatchKey("keyup", {key}, 0)',
                     '    If Len(mParityFailure) > 0 Then Err.Raise 5, "ParityKeyboard", mParityFailure',
                     f'    S = S & {literal(name + "~" + metric + "~" + step + "~")} & mParityEvents & vbLf']
    for c in walk(form['controls']):
        if c['kind'] != 'ListBox':
            continue
        point = next(p for p in points if p['control'].rsplit('.', 1)[-1] == c['name'])
        name, (x, y) = point['control'], point['point_pt']
        body += [f'    E = CalcFormsHostReducer.Dispatch("mousedown", {x}, {y}, 1, 0)',
                 f'    E = CalcFormsHostReducer.Dispatch("mouseup", {x}, {y}, 1, 0)',
                 f'    S = S & {literal(name + "~scrolling~initial~")} & ParityScroll(True) & vbLf']
        for step, key in [('page_down_1', 34), ('page_down_2', 34), ('home', 36)]:
            body += [f'    E = CalcFormsHostReducer.DispatchKey("keydown", {key}, 0)',
                     f'    E = CalcFormsHostReducer.DispatchKey("keyup", {key}, 0)',
                     f'    S = S & {literal(name + "~scrolling~" + step + "~")} & ParityScroll(False) & vbLf']
    body += ['    ParityKeyboardMeasurements = S', '    Exit Function', 'Failed:',
             '    ParityKeyboardMeasurements = "CALCFORMS_NATIVE_ERROR:keyboard:" & CStr(Err.Number) & ":" & Err.Description', 'End Function']
    return source + '\n' + '\n'.join(body) + '\n'


def parse(text):
    if not isinstance(text, str) or 'CALCFORMS_NATIVE_ERROR:' in text:
        raise ValueError('Keyboard/scroll probe failed: ' + str(text))
    result = {}
    for line in text.splitlines():
        name, metric, step, value = line.split('~', 3)
        expected = {'enter_default': ['enter'], 'escape_cancel': ['escape'],
                    'scrolling': ['initial', 'page_down_1', 'page_down_2', 'home']}
        if metric not in expected:
            raise ValueError('Unknown keyboard/scroll metric')
        rows = result.setdefault(name, {}).setdefault(metric, [])
        if len(rows) >= len(expected[metric]) or step != expected[metric][len(rows)]:
            raise ValueError('Invalid keyboard/scroll phase order')
        rows.append(dict(step=step, value=value))
    if not result:
        raise ValueError('No keyboard observations')
    for metrics in result.values():
        if any(len(rows) != len(expected[metric]) for metric, rows in metrics.items()):
            raise ValueError('Incomplete keyboard/scroll observations')
    return result
