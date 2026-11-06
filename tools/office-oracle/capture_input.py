"""Measure actual native traversal/click targets using only owned private HWNDs."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess

import win32gui

from input_probes import native_source, runtime_source, paths, parse
from layout_corpus import ROOT, load_corpus, runtime_source as authored_source
from layout_measurements import native_controls
from native_accessibility import accessible, location, property_value, focus_name, post_key, click
from owned_excel import run_owned_excel
from probe_source import validate_probe_source
from workbook_comparison_session import windows

ENTRY = '''Option Explicit
Public Function ParityInputTrace(ByVal Reset As Boolean) As String
    On Error GoTo Failed
    Dim F As Object
    Set F = LayoutCaptureForm()
    ParityInputTrace = F.ParityInputTrace(Reset)
    Exit Function
Failed:
    ParityInputTrace = "CALCFORMS_NATIVE_ERROR:" & CStr(Err.Number) & ":" & Err.Description
End Function
'''


def capture(owner_path, output, prepared=False):
    output = output.resolve()
    if not output.is_relative_to(ROOT) or output.exists():
        raise ValueError('Use a fresh repo-local output directory')
    output.mkdir(parents=True)
    corpus, results = load_corpus(), []
    binary = ROOT / 'target/debug/examples/layout_probe.exe'
    digest = hashlib.sha256(binary.read_bytes()).hexdigest()

    def action(excel, owner, directory):
        book = excel.Workbooks.Item('layout-corpus.xlsm')
        if Path(book.FullName).resolve() != directory / 'corpus/layout-corpus.xlsm':
            raise ValueError('Native book is not owned by this session')
        for form in corpus['forms']:
            module = book.VBProject.VBComponents.Item(form['name']).CodeModule
            original = module.Lines(1, module.CountOfLines)
            if 'ParityMeasurements' not in original or ('ParityInputTrace' in original) != prepared:
                raise ValueError('Requires exactly the prepared programmatic probe')
            source = native_source(form)
            validate_probe_source(source)
            if prepared:
                if source.strip() not in original.replace('\r\n', '\n'):
                    raise ValueError('Installed native input source differs')
            else:
                module.AddFromString(source)
            (output / (form['name'] + '-native.bas')).write_text(source, encoding='utf-8', newline='\n')
        validate_probe_source(ENTRY)
        if prepared:
            module = book.VBProject.VBComponents.Item('ParityInputEntry')
            if module.CodeModule.Lines(1, module.CodeModule.CountOfLines).replace('\r\n', '\n').strip() != ENTRY.strip():
                raise ValueError('Installed native input entry differs')
        else:
            module = book.VBProject.VBComponents.Add(1)
            module.Name = 'ParityInputEntry'
            module.CodeModule.AddFromString(ENTRY)
        (output / 'native-entry.bas').write_text(ENTRY, encoding='utf-8', newline='\n')
        prefix = "'" + book.Name + "'!"
        for form in corpus['forms']:
            for zoom in (100, 150):
                excel.Run(prefix + 'LayoutShow', form['name'], form['width'], form['height'], zoom)
                f = excel.Run(prefix + 'LayoutCaptureForm')
                root = windows(owner['excel_pid'], form['caption'])[0]
                origin = list(win32gui.ClientToScreen(root, (0, 0)))
                size = list(win32gui.GetClientRect(root)[2:])
                scale = size[0] / form['width'], size[1] / form['height']
                native_facts = excel.Run(prefix + 'LayoutFacts')
                kinds = {name.rsplit('.', 1)[-1]: c['kind'] for name, c in native_controls(native_facts, form['name']).items()}
                initial = focus_name(f, kinds)
                cycle = [initial]
                for _ in range(len(paths(form)) + 3):
                    post_key(root, owner['excel_pid'], 9)
                    cycle.append(focus_name(f, kinds))
                    if cycle[-1] == initial:
                        break
                if cycle[-1] != initial:
                    raise ValueError('Native Tab cycle did not close')
                repeated_cycle = [initial]
                for _ in range(len(paths(form)) + 3):
                    post_key(root, owner['excel_pid'], 9)
                    repeated_cycle.append(focus_name(f, kinds))
                    if repeated_cycle[-1] == initial:
                        break
                if repeated_cycle != cycle:
                    raise ValueError('Native Tab cycle is not repeatable')
                raw = '@initial~' + initial + '\n' + ''.join('@visit~' + name + '\n' for name in cycle)
                points = []
                for name, path in paths(form).items():
                    current = f
                    for part in path.split('.'):
                        current = current.Controls.Item(part)
                    acc = accessible(current)
                    try:
                        x, y, w, h = location(acc)
                        role = property_value(acc, 'accRole')
                    finally:
                        acc.close()
                    # An empty Frame corner avoids its real child controls.
                    px, py = (x + w - 4, y + h - 4) if role == 20 else (x + w // 2, y + h // 2)
                    pt = [round((px - origin[0]) / scale[0]), round((py - origin[1]) / scale[1])]
                    screen = [origin[i] + round(pt[i] * scale[i]) for i in range(2)]
                    if not x <= screen[0] < x + w or not y <= screen[1] < y + h:
                        raise ValueError('Quantized point escaped its observed native site')
                    excel.Run(prefix + 'ParityInputTrace', True)
                    click(root, owner['excel_pid'], screen)
                    trace = excel.Run(prefix + 'ParityInputTrace', False)
                    if 'CALCFORMS_NATIVE_ERROR:' in trace:
                        raise ValueError(trace)
                    raw += path + '~hit_testing~interior~' + trace + '\n'
                    points.append(dict(control=path, point_pt=pt, screen_point_px=screen,
                                       native_accessible_rect_px=[x, y, w, h], role=role, native_trace=trace))
                (output / f'{form["name"]}-{zoom}-native.json').write_text(json.dumps(dict(native=raw, points=points,
                    client_origin_px=origin, client_size_px=size, native_control_kinds=kinds), indent=2) + '\n', encoding='utf-8', newline='\n')
                print('native', form['name'], zoom, cycle, flush=True)
                source = runtime_source(authored_source(form, corpus), form, points)
                source_path = output / f'{form["name"]}-{zoom}-runtime.cls'
                source_path.write_text(source, encoding='utf-8', newline='\n')
                command = [str(binary), str(source_path), form['name'], str(form['width']), str(form['height']),
                           str(zoom / 100), str(output / 'unused-scene.json'), form['caption'], corpus['font'], '--measure', 'ParityInputMeasurements']
                process = subprocess.run(command, cwd=ROOT, capture_output=True, text=True, timeout=180)
                (output / f'{form["name"]}-{zoom}-runtime.txt').write_text(process.stdout + process.stderr, encoding='utf-8', newline='\n')
                if process.returncode:
                    raise RuntimeError(process.stdout + process.stderr)
                actual = json.loads(process.stdout.splitlines()[-1])['measurements']
                results.append(dict(form=form['name'], zoom=zoom, native=raw, calcforms=actual,
                                    points=points, client_origin_px=origin, client_size_px=size,
                                    native_facts=native_facts, repeated_native_tab_cycle=repeated_cycle,
                                    native_parsed=parse(raw), calcforms_parsed=parse(actual)))
                (output / 'observations.json').write_text(json.dumps(dict(schema='calcforms.private_input.v1', owner=owner,
                    runtime_sha256=digest, input='owned private-window messages; no system input/focus/desktop switch', observations=results), indent=2) + '\n', encoding='utf-8', newline='\n')
                print(form['name'], zoom, cycle, flush=True)
        return dict(observations=len(results), additional_excel_launches=0)

    print(json.dumps(run_owned_excel(owner_path, action)))
    manifest = {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(output.iterdir()) if p.is_file()}
    (output / 'files.json').write_text(json.dumps(manifest, indent=2) + '\n', encoding='utf-8', newline='\n')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--owner', required=True, type=Path)
    parser.add_argument('--out', required=True, type=Path)
    parser.add_argument('--prepared', action='store_true', help='verify and reuse exactly the existing observer source')
    args = parser.parse_args()
    capture(args.owner, args.out, args.prepared)
