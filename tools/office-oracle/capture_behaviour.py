"""Observe matching programmatic scenarios in the one already-owned Excel/VM3."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess

from behaviour_probes import instrument_runtime, parse, probe_source
from layout_corpus import ROOT, load_corpus, runtime_source
from owned_excel import run_owned_excel
from probe_source import validate_probe_source

ENTRY = '''Option Explicit
Public Function ParityNativeMeasurements() As String
    On Error GoTo Failed
    Dim F As Object
    Set F = LayoutCaptureForm()
    ParityNativeMeasurements = F.ParityMeasurements()
    Exit Function
Failed:
    ParityNativeMeasurements = "CALCFORMS_NATIVE_ERROR:" & CStr(Err.Number) & ":" & Err.Description
End Function
'''


def capture(owner_path, output):
    output = output.resolve()
    if not output.is_relative_to(ROOT) or output.exists():
        raise ValueError('Use a fresh repo-local output directory')
    output.mkdir(parents=True)
    corpus = load_corpus()
    binary = ROOT / 'target/debug/examples/layout_probe.exe'
    binary_hash = hashlib.sha256(binary.read_bytes()).hexdigest()
    results = []

    def action(excel, owner, directory):
        book = excel.Workbooks.Item('layout-corpus.xlsm')
        if Path(book.FullName).resolve() != directory / 'corpus/layout-corpus.xlsm':
            raise ValueError('Authored book does not belong to this capture session')
        for form in corpus['forms']:
            module = book.VBProject.VBComponents.Item(form['name']).CodeModule
            original = module.Lines(1, module.CountOfLines)
            if 'ParityMeasurements' in original:
                raise ValueError('Behaviour probe is already installed')
            native = original.replace('\r\n', '\n').replace('\r', '\n').replace('Option Explicit', 'Option Explicit\nPrivate mParityEvents As String\nPrivate mParityFailure As String', 1) + '\n' + probe_source(form)
            validate_probe_source(native)
            module.DeleteLines(1, module.CountOfLines)
            module.AddFromString(native)
            (output / (form['name'] + '-native.bas')).write_text(native, encoding='utf-8', newline='\n')
            runtime = instrument_runtime(runtime_source(form, corpus), form)
            (output / (form['name'] + '-runtime.cls')).write_text(runtime, encoding='utf-8', newline='\n')
        validate_probe_source(ENTRY)
        module = book.VBProject.VBComponents.Add(1)
        module.Name = 'ParityBehaviourEntry'
        module.CodeModule.AddFromString(ENTRY)
        (output / 'native-entry.bas').write_text(ENTRY, encoding='utf-8', newline='\n')
        prefix = "'" + book.Name + "'!"
        for form in corpus['forms']:
            for zoom in (100, 150):
                excel.Run(prefix + 'LayoutShow', form['name'], form['width'], form['height'], zoom)
                native = excel.Run(prefix + 'ParityNativeMeasurements')
                target = output / (form['name'] + '-runtime.cls')
                command = [str(binary), str(target), form['name'], str(form['width']), str(form['height']),
                           str(zoom / 100), str(output / 'unused-scene.json'), form['caption'], corpus['font'], '--measure', 'ParityMeasurements']
                process = subprocess.run(command, cwd=ROOT, capture_output=True, text=True, timeout=180,
                                         creationflags=subprocess.CREATE_NO_WINDOW)
                (output / f'{form["name"]}-{zoom}-runtime.txt').write_text(process.stdout + process.stderr, encoding='utf-8', newline='\n')
                if process.returncode:
                    raise RuntimeError(process.stdout + process.stderr)
                runtime = json.loads(process.stdout.splitlines()[-1])['measurements']
                results.append(dict(form=form['name'], zoom=zoom, native=native, calcforms=runtime,
                                    native_parsed=parse(native), calcforms_parsed=parse(runtime)))
                (output / 'observations.json').write_text(json.dumps(dict(schema='calcforms.programmatic_behaviour.v1',
                    owner=owner, runtime_sha256=binary_hash, observations=results), indent=2) + '\n', encoding='utf-8', newline='\n')
                print(form['name'], zoom, len(parse(native)), flush=True)
        return dict(observations=len(results), additional_excel_launches=0)

    result = run_owned_excel(owner_path, action)
    manifest = {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(output.iterdir()) if p.is_file()}
    (output / 'files.json').write_text(json.dumps(manifest, indent=2) + '\n', encoding='utf-8', newline='\n')
    print(json.dumps(result))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--owner', required=True, type=Path)
    parser.add_argument('--out', required=True, type=Path)
    args = parser.parse_args()
    capture(args.owner, args.out)
