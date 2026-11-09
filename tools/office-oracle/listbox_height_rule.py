"""Check the ListBox Height rule against every retained native observation (.118).

The rule, read from the 456-row sweep (`.131/native-round12.json`) and the 160 ordered sequences
(`.118/native-round13.json`) of one Excel 16.0.20527:

* The control keeps two heights: the public Height H and a layout height L (undefined at start).
* An explicit Height write sets H only, and also L while L is still undefined.
* A font name/size change, a BorderStyle change, or IntegralHeight False -> True, made while
  IntegralHeight is True, snaps down to whole rows: the input is L when defined, else H; the
  result becomes both H and L, and the result is never above the input.
* The first Show sets H = L when L is defined and leaves H alone when it is not.
* Writing the value a property already holds changes nothing.

`python listbox_height_rule.py` replays all rows and exits non-zero on any disagreement. The
numeric snap (rows of 9.75pt, chrome 3pt at Tahoma 8.25 / 100%; 9.5pt rows at 150%) is a table
here, not a formula: pixel and twip rounding leaves residuals up to 0.25pt that are not modelled.
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

BEADS = Path(__file__).resolve().parents[2] / 'docs/evidence/W010_complete_msforms_object_model_parity/beads'
SWEEP = BEADS / 'oxforms-jbjp.131/native-round12.json'
SEQUENCES = BEADS / 'oxforms-jbjp.118/native-round13.json'

DEFAULT_FONT = ('Tahoma', 8.25)
DISCRIMINATING = []  # snaps whose result exceeds the current H: H cannot have been their input
START_HEIGHT = 72.0


def parse_result(text):
    steps = []
    for part in text.split(';'):
        if not part:
            continue
        key, _, value = part.partition('=')
        steps.append((key, value))
    return steps


def check_sweep():
    data = json.loads(SWEEP.read_text(encoding='utf-8'))
    failures = []
    for row in data['list']:
        fields = dict(part.split('=') for part in row['result'].split(';'))
        changed = (row['font'], row['size']) != DEFAULT_FONT or row['border'] != 0
        # Font and border are written while IntegralHeight still holds its default True; the
        # flag under test is written afterwards, and False -> True never occurs here.
        expected_shown = fields['init'] if changed else fields['set']
        if fields['shown'] != expected_shown or fields['reset'] != fields['set'] or fields['set'] != str(row['height']):
            failures.append(('sweep', row['zoom'], row['font'], row['size'], row['border'], row['integral'], row['height'], row['result']))
    return len(data['list']), failures


def check_sequences():
    data = json.loads(SEQUENCES.read_text(encoding='utf-8'))
    failures = []
    for row in data['list_sequences']:
        steps = parse_result(row['result'])
        if not steps or steps[0][0] != 'start' or steps[0][1] != '72':
            failures.append(('start', row['ops'], row['result']))
            continue
        height, layout = START_HEIGHT, None
        font, border, integral, shown = DEFAULT_FONT, 0, True, False
        for op, observed in steps[1:]:
            code, arg = op[0], op[1:]
            if observed.startswith('top'):
                continue
            value = float(observed)
            snap = None
            if code in 'FA':
                new_font = ('Tahoma' if code == 'F' else 'Arial', float(arg))
                if new_font != font:
                    font = new_font
                    snap = integral
            elif code == 'B':
                if int(arg) != border:
                    border = int(arg)
                    snap = integral
            elif code == 'I':
                new_flag = arg == '1'
                if new_flag != integral:
                    integral = new_flag
                    snap = new_flag
            if code == 'H':
                height = float(arg)
                if layout is None:
                    layout = None  # L stays undefined until the first snap; H is the snap input
                ok = value == height
            elif code == 'S' and not shown:
                shown = True
                if layout is not None:
                    height = layout
                ok = value == height
            elif code in 'FABI' and snap:
                source = layout if layout is not None else height
                if value > height + 1e-9:
                    DISCRIMINATING.append((row['ops'], op, value, height, layout))
                ok = value <= source + 1e-9 and source - value < 20
                height, layout = value, value
            elif code in 'FABIRNSTZ':
                ok = value == height
            else:
                ok = False
            if not ok:
                failures.append(('sequence', row['zoom'], row['ops'], op, observed, 'expected H', height, 'L', layout))
                break
    return len(data['list_sequences']), failures


def main():
    total = 0
    problems = []
    for name, check in (('sweep', check_sweep), ('sequences', check_sequences)):
        count, failures = check()
        total += count
        problems.extend(failures)
        print(f'{name}: {count} rows, {len(failures)} disagree')
    print(f'snaps that start from L, not from the current H: {len(DISCRIMINATING)}')
    if not DISCRIMINATING:
        problems.append('no discriminating snap: the L-versus-H input claim is untested')
    for item in problems[:20]:
        print(item)
    return 1 if problems else 0


if __name__ == '__main__':
    sys.exit(main())
