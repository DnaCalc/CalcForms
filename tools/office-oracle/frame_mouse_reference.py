"""Pair the Frame event correction with unchanged independent native input."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import shutil
from build_behaviour_reference import copy_text_capture
from build_setter_reference import augment
from forms_parity import replay,markdown
from input_probes import upgrade_runtime_tab_signatures
from layout_corpus import ROOT

BEADS=ROOT/'docs/evidence/W010_complete_msforms_object_model_parity/beads'
BASE=BEADS/'oxforms-jbjp.129/final/comparison.json'
DIRECTORY=BEADS/'oxforms-jbjp.130'


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read(path):
    return json.loads(path.read_text(encoding='utf-8'))


def write(path,data):
    path.write_text(json.dumps(data,indent=2)+'\n',encoding='utf-8',newline='\n')


def items(report):
    return {(row['form'],row['zoom'],owner['name'],item['category'],item['metric']):item for row in report['observations'] for owner in [dict(name='(form)',items=row['items']),*row['controls']] for item in owner['items']}


def validate():
    reference=DIRECTORY/'comparison.json'
    data=read(reference)
    if data['baseline_sha256']!=digest(BASE):
        raise ValueError('Earlier measured report changed')
    runtime={suite:read(DIRECTORY/'runtime'/(suite+'.json')) for suite in ('behaviour','input','keyboard')}
    if len({capture['runtime_sha256'] for capture in runtime.values()})!=1:
        raise ValueError('Fresh runtime suites used different binaries')
    for path,checksum in read(DIRECTORY/'inputs.json').items():
        if digest(ROOT/path)!=checksum:
            raise ValueError('Frame input changed: '+path)
    for capture in runtime.values():
        if digest(ROOT/capture['source_reference'])!=capture['source_sha256']:
            raise ValueError('Independent native scenario changed')
        for case in capture['observations']:
            source=DIRECTORY/'runtime'/case['current_source']
            if digest(source)!=case['current_source_sha256'] or source.read_text(encoding='utf-8')!=upgrade_runtime_tab_signatures((ROOT/case['original_source']).read_text(encoding='utf-8')):
                raise ValueError('Frame scenario action/source changed')
    if augment(read(BASE),runtime)!=data['observations']:
        raise ValueError('Frame correction does not regenerate')
    source=(DIRECTORY/'Frame.cls').read_text(encoding='utf-8')
    facts=read(BEADS/'oxforms-jbjp.2/fm20_typelib_facts.v1.json')
    event,=[function for definition in facts['libraries'][0]['types'] if definition['documentation']['name']=='OptionFrameEvents' for function in definition['functions'] if function['documentation']['name']=='MouseDown']
    parameters=', '.join('ByVal '+parameter['name']+' As '+parameter['type']['display'] for parameter in event['parameters'])
    if re.search(r'^Public Event MouseDown\(([^\n]*)\)',source,re.M)[1]!=parameters:
        raise ValueError('Frame event differs from public FM20 signature')
    result=replay(reference)
    if result!=read(reference.with_name('forms-parity.json')) or markdown(result)!=reference.with_name('forms-parity.md').read_text(encoding='utf-8'):
        raise ValueError('Frame report differs from replay')
    if tuple(result['summary'][key] for key in ('pass_count','fail_count','missing_measurements'))!=(1203,415,346):
        raise ValueError('Unexpected full forms report')
    before,after=items(replay(BASE)),items(result)
    if before.keys()!=after.keys() or any(before[key]['native']!=after[key]['native'] for key in before):
        raise ValueError('Earlier native fact or measured row changed')
    gains={key for key in before if before[key]['status']=='fail' and after[key]['status']=='pass'}
    expected={('LayoutContainers',zoom,'Group','behaviour','hit_testing') for zoom in (100,150)}
    if gains!=expected or any(before[key]['status']=='pass' and after[key]['status']=='fail' for key in before):
        raise ValueError('Unexpected gains or regressions')
    print('FORMS PARITY: 1203 pass / 415 fail; 346 missing; two measured Frame gains, no regressions')


def build(measurements):
    DIRECTORY.mkdir(exist_ok=True)
    copy_text_capture(measurements,DIRECTORY/'runtime')
    base=read(BASE)
    runtime={suite:read(DIRECTORY/'runtime'/(suite+'.json')) for suite in ('behaviour','input','keyboard')}
    rows=augment(base,runtime)
    for row in rows:
        for artifact in row['images']:
            shutil.copyfile(BASE.parent/artifact['file'],DIRECTORY/artifact['file'])
    shutil.copyfile(ROOT/'vba/calcforms/Frame.cls',DIRECTORY/'Frame.cls')
    reference=DIRECTORY/'comparison.json'
    write(reference,dict(schema=base['schema'],owner=base['owner'],baseline_reference=BASE.relative_to(ROOT).as_posix(),baseline_sha256=digest(BASE),observations=rows))
    result=replay(reference)
    write(reference.with_name('forms-parity.json'),result)
    reference.with_name('forms-parity.md').write_text(markdown(result),encoding='utf-8',newline='\n')
    paths=[DIRECTORY/'Frame.cls',BEADS/'oxforms-jbjp.2/fm20_typelib_facts.v1.json']+[path for path in (DIRECTORY/'runtime').iterdir() if path.is_file()]
    write(DIRECTORY/'inputs.json',{path.relative_to(ROOT).as_posix():digest(path) for path in sorted(paths)})
    validate()


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--measurements',type=Path)
    args=parser.parse_args()
    if args.measurements:
        build(args.measurements)
    else:
        validate()
