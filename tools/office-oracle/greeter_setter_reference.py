"""Fill greeter behaviour fields from complete original-handler observations."""
import argparse
import copy
import hashlib
import json
from pathlib import Path
import shutil

from forms_parity import replay, markdown
from layout_corpus import ROOT

BASE = ROOT/'docs/evidence/W010_complete_msforms_object_model_parity/beads/oxforms-jbjp.101/final/comparison.json'
DIRECTORY = BASE.parents[2]/'oxforms-jbjp.125'


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def augment(base, native, actual):
    if native['schema'] != 'calcforms.greeter_setters.v1' or len(native['cases']) != 2:
        raise ValueError('Two native greeter scales are required')
    if not native['original_handlers_unchanged'] or native['workbook_sha256'] != digest(ROOT/'fixtures/workbooks/greeter/workbook-greeter.xlsm'):
        raise ValueError('Original greeter fixture differs')
    rows=copy.deepcopy(base['observations'])
    cases={case['zoom']:case['observations'] for case in native['cases']}
    if set(cases) != {100,150} or any(len(case)!=8 for case in cases.values()):
        raise ValueError('Incomplete setter observations')
    for row in rows:
        if row['form'] != 'greeter':
            continue
        expected=cases[row['zoom']]
        if actual['observations'] != expected:
            raise ValueError('Complete original-handler state/event/selection replay differs')
        for name in ('Prompt','Output','InputName','Loud','Greet'):
            native_rows=[r for r in expected if r['control']==name]
            runtime_rows=[r for r in actual['observations'] if r['control']==name]
            fields=row.setdefault('behaviour_measurements',{}).setdefault(name,{})
            for metric in ('event_order','value_changes','selection'):
                if metric=='selection' and name!='InputName':
                    continue
                if fields.get(metric,{}).get('native') is not None:
                    raise ValueError('Do not replace an earlier native observation')
                def project(items):
                    if metric=='event_order':
                        return [dict(step=r['step'],events=r['events']) for r in items]
                    if metric=='value_changes':
                        return [dict(step=r['step'],member=r['member'],value=r['value'],state=r['after']) for r in items]
                    return [dict(step=r['step'],**r['selection']) for r in items if 'selection' in r]
                fields[metric]=dict(native=project(native_rows),calcforms=project(runtime_rows))
    return rows


def validate(reference):
    data=json.loads(reference.read_text(encoding='utf-8'))
    native_path=DIRECTORY/'native/observations.json'
    actual_path=DIRECTORY/'runtime.json'
    for path,key in ((BASE,'baseline'),(native_path,'native'),(actual_path,'runtime')):
        if data[key+'_sha256']!=digest(path):
            raise ValueError('Greeter input hash changed: '+key)
    base=json.loads(BASE.read_text(encoding='utf-8'))
    expected=augment(base,json.loads(native_path.read_text(encoding='utf-8')),json.loads(actual_path.read_text(encoding='utf-8')))
    for before,after in zip(expected,data['observations'],strict=True):
        if before!=after:
            raise ValueError('Greeter augmentation does not regenerate')
    report=replay(reference)
    if report!=json.loads(reference.with_name('forms-parity.json').read_text(encoding='utf-8')) or markdown(report)!=reference.with_name('forms-parity.md').read_text(encoding='utf-8'):
        raise ValueError('Greeter report differs from replay')
    if tuple(report['summary'][key] for key in ('pass_count','fail_count','missing_measurements')) != (1191,427,356):
        raise ValueError('Unexpected complete forms report')
    print(json.dumps({k:v for k,v in report['summary'].items() if k!='measured_failures'}))


def build(log):
    lines=log.read_text(encoding='utf-8').splitlines()
    actual=json.loads(next(line.split('=',1)[1] for line in lines if line.startswith('CALCFORMS_GREETER_SETTERS=')))
    (DIRECTORY/'runtime.json').write_text(json.dumps(actual,indent=2)+'\n',encoding='utf-8',newline='\n')
    native_path=DIRECTORY/'native/observations.json'
    base=json.loads(BASE.read_text(encoding='utf-8'))
    rows=augment(base,json.loads(native_path.read_text(encoding='utf-8')),actual)
    output=DIRECTORY/'final'
    output.mkdir(exist_ok=False)
    for row in rows:
        for item in row['images']:
            shutil.copyfile(BASE.parent/item['file'],output/item['file'])
    data=dict(schema=base['schema'],owner=base['owner'],baseline_reference=BASE.relative_to(ROOT).as_posix(),
              baseline_sha256=digest(BASE),native_sha256=digest(native_path),runtime_sha256=digest(DIRECTORY/'runtime.json'),observations=rows)
    reference=output/'comparison.json'
    reference.write_text(json.dumps(data,indent=2)+'\n',encoding='utf-8',newline='\n')
    report=replay(reference)
    reference.with_name('forms-parity.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8',newline='\n')
    reference.with_name('forms-parity.md').write_text(markdown(report),encoding='utf-8',newline='\n')
    validate(reference)


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--runtime-log',type=Path)
    args=parser.parse_args()
    if args.runtime_log:
        build(args.runtime_log)
    else:
        validate(DIRECTORY/'final/comparison.json')
