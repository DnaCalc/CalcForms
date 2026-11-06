"""Re-execute pinned VBA scenarios against current production controls, no Office."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import shutil

from layout_corpus import ROOT, load_corpus
from input_probes import upgrade_runtime_tab_signatures


def run(output):
    output = output.resolve()
    if not output.is_relative_to(ROOT) or output.exists():
        raise ValueError('Use a fresh repo-local output directory')
    output.mkdir(parents=True)
    corpus = load_corpus()
    forms = {form['name']: form for form in corpus['forms']}
    evidence = ROOT / 'docs/evidence/W010_complete_msforms_object_model_parity/beads'
    binary = ROOT / 'target/debug/examples/layout_probe.exe'
    binary_digest = hashlib.sha256(binary.read_bytes()).hexdigest()
    # Windows locks executing images. Keep Cargo's build output free to relink.
    copies = ROOT / 'target/oracle-runtime-binaries'
    copies.mkdir(exist_ok=True)
    captured_binary = copies / ('layout_probe-' + binary_digest + '.exe')
    if not captured_binary.exists():
        shutil.copyfile(binary, captured_binary)
    if hashlib.sha256(captured_binary.read_bytes()).hexdigest() != binary_digest:
        raise ValueError('Captured runtime binary digest differs')
    binary = captured_binary
    for suite, bead, child, member in [('behaviour', '107', 'behaviour', 'ParityMeasurements'),
                                      ('input', '107', 'input', 'ParityInputMeasurements'),
                                      ('keyboard', '109', 'keyboard', 'ParityKeyboardMeasurements')]:
        source = evidence / ('oxforms-jbjp.' + bead) / child
        path = source / 'observations.json'
        before = json.loads(path.read_text(encoding='utf-8'))
        cases = []
        for case in before['observations']:
            form = forms[case['form']]
            source_file = form['name'] + ('-runtime.cls' if suite == 'behaviour' else f'-{case["zoom"]}-runtime.cls')
            original = source / source_file
            current = output / f'{suite}-{form["name"]}-{case["zoom"]}.cls'
            current.write_text(upgrade_runtime_tab_signatures(original.read_text(encoding='utf-8')),
                               encoding='utf-8', newline='\n')
            command = [str(binary), str(current), form['name'], str(form['width']), str(form['height']),
                       str(case['zoom'] / 100), str(output / 'unused-scene.json'), form['caption'], corpus['font'], '--measure', member]
            process = subprocess.run(command, cwd=ROOT, capture_output=True, text=True, timeout=180,
                                     creationflags=subprocess.CREATE_NO_WINDOW)
            log = output / f'{suite}-{form["name"]}-{case["zoom"]}.txt'
            log.write_text(process.stdout + process.stderr, encoding='utf-8', newline='\n')
            if process.returncode:
                raise RuntimeError(process.stdout + process.stderr)
            actual = json.loads(process.stdout.splitlines()[-1])['measurements']
            cases.append(dict(form=form['name'], zoom=case['zoom'], calcforms=actual,
                              original_source=original.relative_to(ROOT).as_posix(),
                              current_source=current.name,
                              current_source_sha256=hashlib.sha256(current.read_bytes()).hexdigest()))
            print(suite, form['name'], case['zoom'], flush=True)
        (output / (suite + '.json')).write_text(json.dumps(dict(schema='calcforms.runtime_measurements.v1',
            source_reference=path.relative_to(ROOT).as_posix(), source_sha256=hashlib.sha256(path.read_bytes()).hexdigest(),
            runtime_sha256=binary_digest, observations=cases), indent=2) + '\n', encoding='utf-8', newline='\n')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--out', type=Path, required=True)
    run(parser.parse_args().out)
