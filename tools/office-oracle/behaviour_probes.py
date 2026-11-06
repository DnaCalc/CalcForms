"""Non-production, matching native/VM3 programmatic control scenarios.

Only actual data-changing and selection operations earn behaviour rows. These
scenarios do not establish keyboard, hit-test, scrolling or lifecycle coverage.
"""
from layout_corpus import literal, walk

EVENTS = {
    'TextBox': ['Change'], 'CheckBox': ['Change', 'Click'],
    'OptionButton': ['Change', 'Click'], 'ToggleButton': ['Change', 'Click'],
    'ListBox': ['Change', 'Click'], 'ComboBox': ['Change', 'Click'],
    'TabStrip': ['Change'], 'MultiPage': ['Change'],
    'SpinButton': ['Change', 'SpinUp', 'SpinDown'], 'ScrollBar': ['Change', 'Scroll'],
}


def probe_source(form):
    controls = [c for c in walk(form['controls']) if c['kind'] in EVENTS]
    paths = {}

    def paths_for(children, prefix=''):
        for c in children:
            paths[c['name']] = prefix + c['name']
            paths_for(c.get('children', []), prefix + c['name'] + '.')
    paths_for(form['controls'])
    handlers, functions = [], []
    for c in controls:
        name, kind, path = c['name'], c['kind'], paths[c['name']]
        for event in EVENTS[kind]:
            handlers.append(f'''Private Sub {name}_{event}()
    On Error GoTo Failed
    mParityEvents = mParityEvents & {literal(path + '.' + event + '|')}
    Exit Sub
Failed:
    mParityFailure = "event:" & CStr(Err.Number) & ":" & Err.Description
End Sub''')
        prop = 'Text' if kind == 'TextBox' else 'ListIndex' if kind in {'ComboBox', 'ListBox'} else 'Value'
        value = (literal('Parity probe') if kind == 'TextBox' else 'Not CBool(Original)'
                 if kind in {'CheckBox', 'OptionButton', 'ToggleButton'} else '1' if kind not in {'ComboBox', 'ListBox'} else '2')
        read = f'CStr({name}.{prop})'
        if kind in {'ComboBox', 'ListBox'}:
            read += f' & ";value=" & CStr({name}.Value)'
        body = [f'Private Function Parity_{name}() As String', '    On Error GoTo Failed',
                '    Dim Original As Variant, S As String', f'    Original = {name}.{prop}',
                '    mParityEvents = ""', '    mParityFailure = ""']

        def observe(step):
            body.append(f'    S = S & {literal(path + "~value_changes~" + step + "~")} & {read} & vbLf')
            body.append(f'    S = S & {literal(path + "~event_order~" + step + "~")} & mParityEvents & vbLf')

        observe('initial')
        for step, expression in [('set', value), ('repeat', value), ('restore', 'Original')]:
            body.append(f'    {name}.{prop} = {expression}')
            observe(step)
        if kind == 'TextBox':
            # A dedicated literal gives the same selection domain in both engines.
            body += [f'    {name}.Text = "Alpha Beta"', f'    {name}.SelStart = 2', f'    {name}.SelLength = 4',
                     f'    S = S & {literal(path + "~selection~range~")} & CStr({name}.SelStart) & ";" & CStr({name}.SelLength) & ";" & {name}.SelText & vbLf',
                     f'    {name}.SelText = "X"',
                     f'    S = S & {literal(path + "~selection~replace~")} & {name}.Text & ";" & CStr({name}.SelStart) & ";" & CStr({name}.SelLength) & vbLf',
                     f'    {name}.Text = Original']
        elif kind in {'ListBox', 'ComboBox', 'TabStrip', 'MultiPage'}:
            body += [f'    {name}.{prop} = 1',
                     f'    S = S & {literal(path + "~selection~select~")} & CStr({name}.{prop}) & vbLf',
                     f'    {name}.{prop} = Original']
        body += ['    If Len(mParityFailure) > 0 Then Err.Raise 5, "Parity", mParityFailure',
                 f'    Parity_{name} = S', '    Exit Function', 'Failed:',
                 f'    Parity_{name} = "CALCFORMS_NATIVE_ERROR:{path}:" & CStr(Err.Number) & ":" & Err.Description & vbLf', 'End Function']
        functions.append('\n'.join(body))
    main = ['Public Function ParityMeasurements() As String', '    On Error GoTo Failed', '    Dim S As String']
    main += [f'    S = S & Parity_{c["name"]}()' for c in controls]
    main += ['    ParityMeasurements = S', '    Exit Function', 'Failed:',
             '    ParityMeasurements = "CALCFORMS_NATIVE_ERROR:" & CStr(Err.Number) & ":" & Err.Description', 'End Function']
    return '\n\n'.join(['\n'.join(main), *functions, *handlers]) + '\n'


def instrument_runtime(source, form):
    source = source.replace('Option Explicit', 'Option Explicit\nPrivate mParityEvents As String\nPrivate mParityFailure As String', 1)
    for c in walk(form['controls']):
        if c['kind'] in EVENTS:
            source = source.replace('Public ' + c['name'] + ' As ', 'Public WithEvents ' + c['name'] + ' As ', 1)
    return source + '\n' + probe_source(form)


def parse(text):
    if not isinstance(text, str) or 'CALCFORMS_NATIVE_ERROR:' in text:
        raise ValueError('Native/runtime behaviour probe failed: ' + str(text))
    result = {}
    for line in text.splitlines():
        name, metric, step, value = line.split('~', 3)
        if metric not in {'event_order', 'value_changes', 'selection'}:
            raise ValueError('Unknown measured behaviour')
        rows = result.setdefault(name, {}).setdefault(metric, [])
        if any(row['step'] == step for row in rows):
            raise ValueError('Duplicate measured step')
        rows.append(dict(step=step, value=value))
    if not result:
        raise ValueError('No behaviour measurements')
    for name, metrics in result.items():
        if any(not part.isascii() or not part.isidentifier() for part in name.split('.')):
            raise ValueError('Invalid measured control path')
        if not {'event_order', 'value_changes'} <= metrics.keys():
            raise ValueError('Missing paired value/event observations')
        for metric in ('event_order', 'value_changes'):
            if [row['step'] for row in metrics[metric]] != ['initial', 'set', 'repeat', 'restore']:
                raise ValueError('Incomplete ordered behaviour observations')
        if 'selection' in metrics and [row['step'] for row in metrics['selection']] not in (['range', 'replace'], ['select']):
            raise ValueError('Incomplete selection observations')
    return result
