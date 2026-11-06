"""Typed source and replay for private-window traversal/interior-click scenarios."""
from behaviour_probes import instrument_runtime
from layout_corpus import ROOT, literal, walk
import json
import re

EVENT_CLASSES = {'Label': 'LabelControlEvents', 'TextBox': 'MdcTextEvents', 'CommandButton': 'CommandButtonEvents',
                 'CheckBox': 'MdcCheckBoxEvents', 'OptionButton': 'MdcOptionButtonEvents',
                 'ToggleButton': 'MdcToggleButtonEvents', 'ComboBox': 'MdcComboEvents', 'ListBox': 'MdcListEvents',
                 'Frame': 'OptionFrameEvents', 'Image': 'ImageEvents', 'TabStrip': 'TabStripEvents', 'MultiPage': 'MultiPageEvents'}


def upgrade_runtime_tab_signatures(source):
    """Adapt historical probe declarations to the corrected public event facade.

    Keep old generators reproducible. Only the formerly omitted, unused Index
    parameter changes; scenario actions and independent native traces do not.
    """
    names = re.findall(r'(?:Public|Private) WithEvents (\w+) As (?:TabStrip|MultiPage)\b', source)
    for name in names:
        for event in ('MouseDown', 'MouseUp'):
            source = source.replace(f'Private Sub {name}_{event}(ByVal Button',
                                    f'Private Sub {name}_{event}(ByVal Index As Long, ByVal Button')
    return source


def validate_native_signatures(form, source):
    facts = json.loads((ROOT / 'docs/evidence/W010_complete_msforms_object_model_parity/beads/oxforms-jbjp.2/fm20_typelib_facts.v1.json').read_text(encoding='utf-8'))
    types = {t['documentation']['name']: t for t in facts['libraries'][0]['types']}
    for name, event_class in [('UserForm', 'FormEvents'), *[(c['name'], EVENT_CLASSES.get(c['kind'])) for c in walk(form['controls'])]]:
        match = re.search(r'Private Sub ' + re.escape(name) + r'_MouseDown\(([^\n]*)\)', source)
        if event_class is None:
            if match:
                raise ValueError('No public native MouseDown source for ' + name)
            continue
        event, = [f for f in types[event_class]['functions'] if f['documentation']['name'] == 'MouseDown']
        expected = ', '.join('ByVal ' + p['name'] + ' As ' + p['type']['display'] for p in event['parameters'])
        if match is None or match[1].lower() != expected.lower():
            raise ValueError('Native MouseDown signature differs from public FM20 facts: ' + name)


def paths(form):
    result = {}
    def add(children, prefix=''):
        for c in children:
            result[c['name']] = prefix + c['name']
            add(c.get('children', []), prefix + c['name'] + '.')
    add(form['controls'])
    return result


def native_source(form, native=True):
    names = paths(form)
    kinds = {c['name']: c['kind'] for c in walk(form['controls'])}
    source = ['''Public Function ParityInputTrace(ByVal Reset As Boolean) As String
    On Error GoTo Failed
    If Reset Then
        mParityEvents = ""
        mParityFailure = ""
    End If
    If Len(mParityFailure) > 0 Then Err.Raise 5, "ParityInput", mParityFailure
    ParityInputTrace = mParityEvents
    Exit Function
Failed:
    ParityInputTrace = "CALCFORMS_NATIVE_ERROR:" & CStr(Err.Number) & ":" & Err.Description
End Function''']
    for name, path in names.items():
        if native and kinds[name] not in EVENT_CLASSES:
            continue
        index = 'ByVal Index As Long, ' if native and kinds[name] in {'TabStrip', 'MultiPage'} else ''
        source.append(f'''Private Sub {name}_MouseDown({index}ByVal Button As Integer, ByVal Shift As Integer, ByVal X As Single, ByVal Y As Single)
    On Error GoTo Failed
    mParityEvents = mParityEvents & {literal(path + '.MouseDown|')}
    Exit Sub
Failed:
    mParityFailure = "mousedown:" & CStr(Err.Number) & ":" & Err.Description
End Sub''')
    source.append('''Private Sub UserForm_MouseDown(ByVal Button As Integer, ByVal Shift As Integer, ByVal X As Single, ByVal Y As Single)
    On Error GoTo Failed
    mParityEvents = mParityEvents & "(form).MouseDown|"
    Exit Sub
Failed:
    mParityFailure = "form-mousedown:" & CStr(Err.Number) & ":" & Err.Description
End Sub''')
    result = '\n\n'.join(source) + '\n'
    if native:
        validate_native_signatures(form, result)
    return result


def runtime_source(source, form, points):
    source = instrument_runtime(source, form)
    for c in walk(form['controls']):
        source = source.replace('Public ' + c['name'] + ' As ', 'Public WithEvents ' + c['name'] + ' As ', 1)
    source += '\n' + native_source(form, native=False)
    body = ['Public Function ParityInputMeasurements() As String', '    On Error GoTo Failed',
            '    Dim S As String, E As String, First As String, I As Long',
            '    S = "@initial~" & CalcFormsHostReducer.FocusName & vbLf',
            '    E = CalcFormsHostReducer.DispatchKey("keydown", 9, 0)',
            '    E = CalcFormsHostReducer.DispatchKey("keyup", 9, 0)',
            '    First = CalcFormsHostReducer.FocusName',
            '    S = S & "@visit~" & First & vbLf',
            f'    For I = 1 To {len(paths(form)) + 3}',
            '        E = CalcFormsHostReducer.DispatchKey("keydown", 9, 0)',
            '        E = CalcFormsHostReducer.DispatchKey("keyup", 9, 0)',
            '        S = S & "@visit~" & CalcFormsHostReducer.FocusName & vbLf',
            '        If CalcFormsHostReducer.FocusName = First Then Exit For',
            '    Next',
            '    If CalcFormsHostReducer.FocusName <> First Then Err.Raise 5, "ParityInput", "Tab cycle did not close"']
    for point in points:
        name = point['control']
        x, y = point['point_pt']
        body += ['    mParityEvents = ""', '    mParityFailure = ""',
                 f'    E = CalcFormsHostReducer.Dispatch("mousedown", {x}, {y}, 1, 0)',
                 f'    E = CalcFormsHostReducer.Dispatch("mouseup", {x}, {y}, 1, 0)',
                 '    If Len(mParityFailure) > 0 Then Err.Raise 5, "ParityInput", mParityFailure',
                 f'    S = S & {literal(name + "~hit_testing~interior~")} & mParityEvents & vbLf']
    body += ['    ParityInputMeasurements = S', '    Exit Function', 'Failed:',
             '    ParityInputMeasurements = "CALCFORMS_NATIVE_ERROR:" & CStr(Err.Number) & ":" & Err.Description', 'End Function']
    return source + '\n' + '\n'.join(body) + '\n'


def parse(text):
    if not isinstance(text, str) or 'CALCFORMS_NATIVE_ERROR:' in text:
        raise ValueError('Private input probe failed: ' + str(text))
    initial, cycle, hits = None, [], {}
    for line in text.splitlines():
        if line.startswith('@initial~'):
            if initial is not None:
                raise ValueError('Duplicate initial focus')
            initial = line.split('~', 1)[1]
        elif line.startswith('@visit~'):
            cycle.append(line.split('~', 1)[1])
        else:
            name, metric, step, trace = line.split('~', 3)
            if metric != 'hit_testing' or step != 'interior' or name in hits:
                raise ValueError('Invalid/duplicate interior hit observation')
            events = [event for event in trace.split('|') if event]
            down = [event.rsplit('.', 1)[0] for event in events if event.endswith('.MouseDown')]
            hits[name] = down or sorted({event.rsplit('.', 1)[0] for event in events})
    if initial is None or len(cycle) < 2 or cycle[0] != cycle[-1] or '' in cycle:
        raise ValueError('Missing or incomplete observed Tab cycle')
    return dict(initial_focus=initial, tab_cycle=cycle, hits=hits)


def pair(form, native, actual):
    n, a = parse(native), parse(actual)
    names = paths(form)
    kinds = {c['name']: c['kind'] for c in walk(form['controls'])}
    if any(kinds.get(data['tab_cycle'][0]) in {'Frame', 'TabStrip', 'MultiPage'} for data in (n, a)):
        raise ValueError('Container-first cycles require a finer focus identity')
    if set(n['hits']) != set(names.values()) or n['hits'].keys() != a['hits'].keys():
        raise ValueError('Interior hit coverage differs')
    result = {}
    for name, path in names.items():
        def visits(data):
            cycle = data['tab_cycle']
            return [dict(position=i, next=cycle[i + 1]) for i, value in enumerate(cycle[:-1]) if value == name]
        native_hit = n['hits'][path]
        if not native_hit and kinds[name] in {'SpinButton', 'ScrollBar'}:
            native_hit = None  # No event proving the target on this range control.
        result[path] = dict(tab_order=dict(native=visits(n), calcforms=visits(a)),
                            hit_testing=dict(native=native_hit, calcforms=a['hits'][path]))
    return result, dict(native=n, calcforms=a)
