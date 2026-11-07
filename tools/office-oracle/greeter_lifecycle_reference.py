"""Pair fresh production transcripts and in-process lifecycle observations."""
import argparse
import copy
import hashlib
import json
from pathlib import Path
import shutil
from build_setter_reference import augment as augment_runtime
from build_behaviour_reference import copy_text_capture
from capture_greeter_lifecycle_inprocess import parse
from forms_parity import replay,markdown
from input_probes import upgrade_runtime_tab_signatures
from layout_corpus import ROOT

BEADS=ROOT/'docs/evidence/W010_complete_msforms_object_model_parity/beads'
BASE=BEADS/'oxforms-jbjp.125/final/comparison.json'
DIRECTORY=BEADS/'oxforms-jbjp.129'


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read(path):
    return json.loads(path.read_text(encoding='utf-8'))


def write(path,data):
    path.write_text(json.dumps(data,indent=2)+'\n',encoding='utf-8',newline='\n')


def augment(base,native,actual,runtime):
    if not native['original_handlers_unchanged'] or native['workbook_sha256']!=digest(ROOT/'fixtures/workbooks/greeter/workbook-greeter.xlsm'):
        raise ValueError('Original greeter input differs')
    cases={case['zoom']:case for case in native['cases']}
    if set(cases)!={100,150}:
        raise ValueError('Both native scales are required')
    rows=augment_runtime(base,runtime)
    for row in rows:
        if row['form']!='greeter':
            continue
        case=cases[row['zoom']]
        expected=parse(case['result'])
        if expected!=case['observations'] or expected!=actual['observations']:
            raise ValueError('Complete in-process lifecycle replay differs')
        for name in ('Prompt','Output','InputName','Loud','Greet'):
            fields=row['behaviour_measurements'].setdefault(name,{})
            if fields.get('show_hide_unload',{}).get('native') is not None:
                raise ValueError('Do not replace an earlier native lifecycle measurement')
            project=lambda items:[dict(step=item['step'],form_visible=item['form_visible'],**item['values'][name]) for item in items]
            fields['show_hide_unload']=dict(native=project(expected),calcforms=project(actual['observations']))
    return rows


def validate():
    reference=DIRECTORY/'final/comparison.json'
    data=read(reference)
    if data['baseline_sha256']!=digest(BASE):
        raise ValueError('Earlier measured report changed')
    for relative,checksum in read(DIRECTORY/'inputs.json').items():
        if digest(ROOT/relative)!=checksum:
            raise ValueError('Lifecycle input changed: '+relative)
    native=read(DIRECTORY/'native-vba/observations.json')
    runtime={suite:read(DIRECTORY/'runtime'/(suite+'.json')) for suite in ('behaviour','input','keyboard')}
    if len({record['runtime_sha256'] for record in runtime.values()})!=1:
        raise ValueError('Fresh runtime suites used different binaries')
    for suite in runtime.values():
        if digest(ROOT/suite['source_reference'])!=suite['source_sha256']:
            raise ValueError('Independent native scenario changed')
        for case in suite['observations']:
            source=DIRECTORY/'runtime'/case['current_source']
            original=(ROOT/case['original_source']).read_text(encoding='utf-8')
            if digest(source)!=case['current_source_sha256'] or source.read_text(encoding='utf-8')!=upgrade_runtime_tab_signatures(original):
                raise ValueError('Current runtime scenario changed')
    expected=augment(read(BASE),native,read(DIRECTORY/'runtime-lifecycle.json'),runtime)
    if expected!=data['observations']:
        raise ValueError('Fresh measured report does not regenerate')
    for name,checksum in data['production_sources'].items():
        if digest(DIRECTORY/'sources'/name)!=checksum:
            raise ValueError('Archived production source differs')
    result=replay(reference)
    if result!=read(reference.with_name('forms-parity.json')) or markdown(result)!=reference.with_name('forms-parity.md').read_text(encoding='utf-8'):
        raise ValueError('Lifecycle report differs from replay')
    previous=replay(BASE)
    def items(report):
        return {(row['form'],row['zoom'],owner['name'],item['category'],item['metric']):item for row in report['observations'] for owner in [dict(name='(form)',items=row['items']),*row['controls']] for item in owner['items']}
    old,new=items(previous),items(result)
    if old.keys()!=new.keys():
        raise ValueError('Earlier measured row coverage changed')
    for key in old:
        if old[key]['native']!=new[key]['native'] and not (key[0]=='greeter' and key[4]=='show_hide_unload' and old[key]['native'] is None):
            raise ValueError('An earlier native fact changed: '+str(key))
    changes=dict(gains=[list(key) for key in old if old[key]['status']=='fail' and new[key]['status']=='pass'],regressions=[list(key) for key in old if old[key]['status']=='pass' and new[key]['status']=='fail'])
    if changes!=read(DIRECTORY/'changes.json'):
        raise ValueError('Gain/regression accounting changed')
    print(json.dumps({key:value for key,value in result['summary'].items() if key!='measured_failures'}))
    print('Gains '+str(len(changes['gains']))+'; regressions '+str(len(changes['regressions'])))


def build(log,measurements):
    actual=json.loads(next(line.split('=',1)[1] for line in log.read_text(encoding='utf-8').splitlines() if line.startswith('CALCFORMS_GREETER_LIFECYCLE=')))
    write(DIRECTORY/'runtime-lifecycle.json',actual)
    copy_text_capture(measurements,DIRECTORY/'runtime')
    runtime={suite:read(DIRECTORY/'runtime'/(suite+'.json')) for suite in ('behaviour','input','keyboard')}
    base=read(BASE)
    rows=augment(base,read(DIRECTORY/'native-vba/observations.json'),actual,runtime)
    output=DIRECTORY/'final'
    output.mkdir(exist_ok=False)
    for row in rows:
        for artifact in row['images']:
            shutil.copyfile(BASE.parent/artifact['file'],output/artifact['file'])
    paths=['vba/calcforms/'+name for name in ('OxInteractionManager.cls','ListBox.cls','SpinButton.cls','ScrollBar.cls','Controls.cls','runtime/WorkbookFormLifetime.vba')]+['crates/calcforms-calcvba-adapter/src/runtime.rs']
    production={}
    for relative in paths:
        target=DIRECTORY/'sources'/relative
        target.parent.mkdir(parents=True,exist_ok=True)
        shutil.copyfile(ROOT/relative,target)
        production[relative]=digest(target)
    data=dict(schema=base['schema'],owner=base['owner'],baseline_reference=BASE.relative_to(ROOT).as_posix(),baseline_sha256=digest(BASE),production_sources=production,observations=rows)
    reference=output/'comparison.json'
    write(reference,data)
    result=replay(reference)
    write(reference.with_name('forms-parity.json'),result)
    reference.with_name('forms-parity.md').write_text(markdown(result),encoding='utf-8',newline='\n')
    def items(report):
        return {(row['form'],row['zoom'],owner['name'],item['category'],item['metric']):item for row in report['observations'] for owner in [dict(name='(form)',items=row['items']),*row['controls']] for item in owner['items']}
    old,new=items(replay(BASE)),items(result)
    write(DIRECTORY/'changes.json',dict(gains=[list(key) for key in old if old[key]['status']=='fail' and new[key]['status']=='pass'],regressions=[list(key) for key in old if old[key]['status']=='pass' and new[key]['status']=='fail']))
    inputs=[DIRECTORY/'runtime-lifecycle.json']+[path for child in ('native-vba','native-inprocess','native-readback') for path in (DIRECTORY/child).iterdir() if path.is_file()]
    inputs.extend(path for path in (DIRECTORY/'runtime').iterdir() if path.is_file())
    write(DIRECTORY/'inputs.json',{path.relative_to(ROOT).as_posix():digest(path) for path in sorted(inputs)})
    validate()


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--runtime-log',type=Path)
    parser.add_argument('--measurements',type=Path)
    args=parser.parse_args()
    if args.runtime_log and args.measurements:
        build(args.runtime_log,args.measurements)
    else:
        validate()
