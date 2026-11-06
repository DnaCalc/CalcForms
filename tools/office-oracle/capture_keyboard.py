"""Post keys only inside the existing private owned Excel; pair normalized VM3."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess

import win32gui

from build_behaviour_reference import DIRECTORY as INPUT_REFERENCE
from keyboard_probes import parse, runtime_source, shared_source
from input_probes import upgrade_runtime_tab_signatures
from layout_corpus import ROOT, load_corpus, runtime_source as authored_source
from native_accessibility import click, post_key
from owned_excel import run_owned_excel
from probe_source import validate_probe_source
from workbook_comparison_session import windows

ENTRY = '''Option Explicit
Public Function ParityScroll(ByVal Prepare As Boolean) As String
    On Error GoTo Failed
    Dim F As Object
    Set F = LayoutCaptureForm()
    ParityScroll = F.ParityScroll(Prepare)
    Exit Function
Failed:
    ParityScroll = "CALCFORMS_NATIVE_ERROR:scroll-entry:" & CStr(Err.Number) & ":" & Err.Description
End Function
'''


def capture(owner_path, output, prepared=False):
    output = output.resolve()
    if not output.is_relative_to(ROOT) or output.exists():
        raise ValueError('Use a fresh repo-local output directory')
    output.mkdir(parents=True)
    corpus, results = load_corpus(), []
    point_data = json.loads((INPUT_REFERENCE / 'input/observations.json').read_text(encoding='utf-8'))
    cases = {(r['form'], r['zoom']): r for r in point_data['observations']}
    binary = ROOT / 'target/debug/examples/layout_probe.exe'
    digest = hashlib.sha256(binary.read_bytes()).hexdigest()

    def action(excel, owner, directory):
        book = excel.Workbooks.Item('layout-corpus.xlsm')
        if Path(book.FullName).resolve() != directory / 'corpus/layout-corpus.xlsm':
            raise ValueError('Native book is not owned by this session')
        for form in corpus['forms']:
            module = book.VBProject.VBComponents.Item(form['name']).CodeModule
            current = module.Lines(1, module.CountOfLines)
            if 'ParityInputTrace' not in current or ('ParityListSnapshot' in current) != prepared:
                raise ValueError('Requires exactly the prepared input observer')
            source = shared_source(form)
            validate_probe_source(source)
            if prepared:
                if source.strip() not in current.replace('\r\n', '\n'):
                    raise ValueError('Installed keyboard source differs')
            else:
                module.AddFromString(source)
            (output / (form['name'] + '-native.bas')).write_text(source, encoding='utf-8', newline='\n')
        validate_probe_source(ENTRY)
        if prepared:
            module = book.VBProject.VBComponents.Item('ParityKeyboardEntry')
            if module.CodeModule.Lines(1, module.CodeModule.CountOfLines).replace('\r\n', '\n').strip() != ENTRY.strip():
                raise ValueError('Installed keyboard entry differs')
        else:
            module = book.VBProject.VBComponents.Add(1)
            module.Name = 'ParityKeyboardEntry'
            module.CodeModule.AddFromString(ENTRY)
        (output / 'native-entry.bas').write_text(ENTRY, encoding='utf-8', newline='\n')
        prefix = "'" + book.Name + "'!"
        for form in corpus['forms']:
            for zoom in (100, 150):
                case = cases[form['name'], zoom]
                excel.Run(prefix + 'LayoutShow', form['name'], form['width'], form['height'], zoom)
                f = excel.Run(prefix + 'LayoutCaptureForm')
                facts = excel.Run(prefix + 'LayoutFacts')
                if facts != case['native_facts']:
                    raise ValueError('Keyboard geometry differs from observed input points')
                root = windows(owner['excel_pid'], form['caption'])[0]
                origin = win32gui.ClientToScreen(root, (0, 0))
                size = win32gui.GetClientRect(root)[2:]
                scale = size[0] / form['width'], size[1] / form['height']
                raw, visibility = '', []
                def interior(point):
                    screen = [origin[i] + round(point['point_pt'][i] * scale[i]) for i in range(2)]
                    click(root, owner['excel_pid'], screen)
                for point in case['points']:
                    interior(point)
                    for metric, step, key in [('enter_default', 'enter', 13), ('escape_cancel', 'escape', 27)]:
                        excel.Run(prefix + 'ParityInputTrace', True)
                        post_key(root, owner['excel_pid'], key)
                        trace = excel.Run(prefix + 'ParityInputTrace', False)
                        raw += point['control'] + '~' + metric + '~' + step + '~' + trace + '\n'
                        visibility.append(dict(control=point['control'], key=key, native_visible=bool(f.Visible)))
                        if not f.Visible:
                            raise ValueError('Unexpected hidden form prevents later input observations')
                for c in form['controls']:
                    if c['kind'] != 'ListBox':
                        continue
                    point = next(p for p in case['points'] if p['control'] == c['name'])
                    interior(point)
                    raw += c['name'] + '~scrolling~initial~' + excel.Run(prefix + 'ParityScroll', True) + '\n'
                    for step, key in [('page_down_1', 34), ('page_down_2', 34), ('home', 36)]:
                        post_key(root, owner['excel_pid'], key)
                        raw += c['name'] + '~scrolling~' + step + '~' + excel.Run(prefix + 'ParityScroll', False) + '\n'
                source_path = output / f'{form["name"]}-{zoom}-runtime.cls'
                source_path.write_text(upgrade_runtime_tab_signatures(runtime_source(authored_source(form, corpus), form, case['points'])), encoding='utf-8', newline='\n')
                command = [str(binary), str(source_path), form['name'], str(form['width']), str(form['height']),
                           str(zoom / 100), str(output / 'unused-scene.json'), form['caption'], corpus['font'], '--measure', 'ParityKeyboardMeasurements']
                process = subprocess.run(command, cwd=ROOT, capture_output=True, text=True, timeout=180,
                                         creationflags=subprocess.CREATE_NO_WINDOW)
                (output / f'{form["name"]}-{zoom}-runtime.txt').write_text(process.stdout + process.stderr, encoding='utf-8', newline='\n')
                if process.returncode:
                    raise RuntimeError(process.stdout + process.stderr)
                actual = json.loads(process.stdout.splitlines()[-1])['measurements']
                results.append(dict(form=form['name'], zoom=zoom, native=raw, calcforms=actual, native_facts=facts,
                                    native_visibility=visibility,
                                    native_parsed=parse(raw), calcforms_parsed=parse(actual)))
                (output / 'observations.json').write_text(json.dumps(dict(schema='calcforms.keyboard_scroll.v1', owner=owner,
                    runtime_sha256=digest, observations=results), indent=2) + '\n', encoding='utf-8', newline='\n')
                print(form['name'], zoom, len(parse(raw)), flush=True)
        return dict(observations=len(results), additional_excel_launches=0)
    print(json.dumps(run_owned_excel(owner_path, action)))
    manifest = {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(output.iterdir()) if p.is_file()}
    (output / 'files.json').write_text(json.dumps(manifest, indent=2) + '\n', encoding='utf-8', newline='\n')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--owner', required=True, type=Path)
    parser.add_argument('--out', required=True, type=Path)
    parser.add_argument('--prepared', action='store_true')
    args = parser.parse_args()
    capture(args.owner, args.out, args.prepared)
