"""Scripts for the round 14 native probe (.101 fonts, .105 geometry, tab order and common properties).

Each script is a list of lines for the shared interpreter in round14_engine.bas. The same text runs
in Excel and against the CalcForms runtime; the results are compared line by line.
"""

CONTROLS = [
    ('Forms.Label.1', 'Lbl'), ('Forms.TextBox.1', 'Txt'), ('Forms.CommandButton.1', 'Cmd'),
    ('Forms.CheckBox.1', 'Chk'), ('Forms.OptionButton.1', 'Opt'), ('Forms.ToggleButton.1', 'Tog'),
    ('Forms.ListBox.1', 'Lst'), ('Forms.ComboBox.1', 'Cmb'), ('Forms.Frame.1', 'Frm'),
    ('Forms.Image.1', 'Img'), ('Forms.SpinButton.1', 'Spn'), ('Forms.ScrollBar.1', 'Scr'),
    ('Forms.TabStrip.1', 'Tab'), ('Forms.MultiPage.1', 'Mpg'),
]
NAMES = [name for _, name in CONTROLS]
FONT_CONTROLS = ['Lbl', 'Txt', 'Cmd', 'Chk', 'Opt', 'Tog', 'Lst', 'Cmb', 'Frm', 'Tab', 'Mpg', 'Form']
FONT_PROPS = ['Name', 'Size', 'Bold', 'Italic', 'Underline', 'Strikethrough', 'Weight', 'Charset']


def build_controls():
    return [f'add {prog} {name}' for prog, name in CONTROLS]


def tab_script():
    s = build_controls()
    for prop in ('TabStop', 'TabIndex', 'Tag', 'ControlTipText', 'HelpContextID'):
        s.append('snap %s %s' % (prop, ' '.join(NAMES)))
    # Tag, ControlTipText, HelpContextID, TabStop writes and coercions
    for typ, lit in [('t', 'abc'), ('t', '5'), ('l', '5'), ('n', '_'), ('e', '_'), ('d', '2.5')]:
        s += [f'let Txt Tag {typ} {lit}', 'get Txt Tag']
    for typ, lit in [('t', 'tip'), ('l', '7'), ('n', '_')]:
        s += [f'let Txt ControlTipText {typ} {lit}', 'get Txt ControlTipText']
    for typ, lit in [('l', '5'), ('l', '-1'), ('l', '2147483647'), ('d', '2.7'), ('t', '9'), ('t', 'x'), ('n', '_')]:
        s += [f'let Txt HelpContextID {typ} {lit}', 'get Txt HelpContextID']
    for typ, lit in [('b', '0'), ('b', '1'), ('l', '0'), ('l', '5'), ('t', 'x'), ('n', '_')]:
        s += [f'let Txt TabStop {typ} {lit}', 'get Txt TabStop']
    s += ['let Lbl TabStop b 1', 'get Lbl TabStop', 'let Img TabStop b 0', 'get Img TabStop',
          'let Img TabIndex i 1', 'get Img TabIndex']
    # TabIndex moves renumber the peers
    others = ' '.join(n for n in NAMES if n != 'Img')
    s.append('snap TabIndex ' + others)
    for typ, lit in [('i', '0'), ('i', '99'), ('i', '-1'), ('i', '3'), ('i', '3'), ('l', '5'), ('d', '2.6'), ('t', '1'), ('n', '_')]:
        s += [f'let Cmd TabIndex {typ} {lit}', 'snap TabIndex ' + others]
    # containers: TabIndex is local
    s += ['add Forms.TextBox.1 FrA Frm', 'add Forms.CommandButton.1 FrB Frm', 'add Forms.TextBox.1 FrC Frm',
          'snap TabIndex FrA FrB FrC', 'let FrC TabIndex i 0', 'snap TabIndex FrA FrB FrC',
          'let FrA TabIndex i 9', 'snap TabIndex FrA FrB FrC']
    s += ['add Forms.TextBox.1 PgA Mpg#0', 'add Forms.TextBox.1 PgB Mpg#0', 'add Forms.TextBox.1 PgC Mpg#1',
          'snap TabIndex PgA PgB PgC', 'let PgB TabIndex i 0', 'snap TabIndex PgA PgB PgC']
    s += ['snap TabIndex Frm Mpg Tab Txt Cmd']
    # remove and re-add
    rest = ' '.join(n for n in NAMES if n not in ('Img', 'Txt'))
    s += ['remove Txt', 'snap TabIndex ' + rest, 'add Forms.TextBox.1 Txt2', 'snap TabIndex ' + rest + ' Txt2',
          'add Forms.Image.1 Img2', 'add Forms.Label.1 Lbl2', 'snap TabIndex Img2 Lbl2 Txt2']
    return s


def geometry_script():
    s = ['add Forms.TextBox.1 Gx', 'add Forms.Frame.1 Gf', 'add Forms.TextBox.1 Gy Gf', 'snap Left Gx Gy',
         'snap Top Gx Gy', 'snap Width Gx Gy', 'snap Height Gx Gy']
    values = ['0', '0.1', '0.24', '0.25', '0.26', '0.37', '1.5', '10.3', '10.37', '12.5', '33.33', '100.123',
              '1000', '32767', '32768', '40000', '1000000', '-1', '-0.5']
    for ctl in ('Gx', 'Gy'):
        for prop in ('Left', 'Top', 'Width', 'Height'):
            for v in values:
                s += [f'let {ctl} {prop} s {v}', f'get {ctl} {prop}']
    for typ, lit in [('d', '10.3'), ('l', '12'), ('i', '7'), ('t', '14.5'), ('t', 'x'), ('n', '_'), ('e', '_'),
                     ('b', '1'), ('c', '9.75')]:
        s += [f'let Gx Left {typ} {lit}', 'get Gx Left']
    # form geometry and scale
    for prop in ('Width', 'Height', 'InsideWidth', 'InsideHeight', 'Zoom'):
        s.append(f'get Form {prop}')
    for v in ('300.37', '300', '123.456', '10', '0', '-5'):
        s += [f'let Form Width s {v}', 'get Form Width', 'get Form InsideWidth']
        s += [f'let Form Height s {v}', 'get Form Height', 'get Form InsideHeight']
    for typ, lit in [('l', '9'), ('l', '10'), ('l', '100'), ('l', '400'), ('l', '401'), ('l', '0'), ('l', '-1'),
                     ('d', '150.5'), ('t', '150'), ('l', '100')]:
        s += [f'let Form Zoom {typ} {lit}', 'get Form Zoom']
    return s


def font_script():
    s = build_controls()
    for prop in FONT_PROPS:
        s.append('snap Font.%s %s' % (prop, ' '.join(FONT_CONTROLS)))
    for ctl in ('Txt', 'Lst', 'Mpg', 'Form'):
        for typ, lit in [('d', '10'), ('d', '8.3'), ('d', '8.25'), ('d', '0'), ('d', '-1'), ('d', '1000'),
                         ('d', '4000'), ('d', '5.5'), ('t', 'abc'), ('l', '12'), ('s', '9.55'), ('c', '14.75'),
                         ('n', '_')]:
            s += [f'let {ctl} Font.Size {typ} {lit}', f'get {ctl} Font.Size']
        for lit in ('Arial', 'Courier', 'NoSuchFontXyz', 'Tahoma'):
            s += [f'let {ctl} Font.Name t {lit}', f'get {ctl} Font.Name']
        s += [f'let {ctl} Font.Name n _', f'get {ctl} Font.Name']
        for typ, lit in [('b', '1'), ('b', '0')]:
            s += [f'let {ctl} Font.Bold {typ} {lit}', f'get {ctl} Font.Bold', f'get {ctl} Font.Weight']
        for lit in ('700', '500', '600', '1000', '1001', '0', '-5', '400', '900'):
            s += [f'let {ctl} Font.Weight i {lit}', f'get {ctl} Font.Weight', f'get {ctl} Font.Bold']
        for prop in ('Italic', 'Underline', 'Strikethrough'):
            for lit in ('1', '0'):
                s += [f'let {ctl} Font.{prop} b {lit}', f'get {ctl} Font.{prop}']
        for lit in ('0', '2', '255', '256', '-1', '1'):
            s += [f'let {ctl} Font.Charset i {lit}', f'get {ctl} Font.Charset']
    for prop in FONT_PROPS:
        s.append('snap Font.%s %s' % (prop, ' '.join(FONT_CONTROLS)))
    s += ['copyfont Cmb Txt', 'copyfont Chk Lst']
    for prop in FONT_PROPS:
        s.append('snap Font.%s Txt Cmb Lst Chk' % prop)
    s += ['let Txt Font.Size d 11', 'snap Font.Size Txt Cmb']
    return s


SCRIPTS = {'tab': tab_script, 'geometry': geometry_script, 'font': font_script}

if __name__ == '__main__':
    for name, fn in SCRIPTS.items():
        print(name, len(fn()))
