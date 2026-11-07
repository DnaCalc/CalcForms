"""Replay qualified original BeforeUpdate veto, Escape, reuse and reload fields."""
import argparse
import hashlib
import json
from pathlib import Path
from layout_corpus import ROOT

DIRECTORY=ROOT/'docs/evidence/W010_complete_msforms_object_model_parity/beads/oxforms-jbjp.105.1'
NATIVE=DIRECTORY/'run9-validation-key-native/observations.json'
OUTPUT=DIRECTORY/'run9-validation'


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read(path):
    return json.loads(path.read_text(encoding='utf-8'))


def write(path,data):
    path.write_text(json.dumps(data,indent=2)+'\n',encoding='utf-8',newline='\n')


def compare(native,actual):
    if native['qualified_validation'] is not True or not native['original_handlers_unchanged']:
        raise ValueError('Native BeforeUpdate veto was not qualified')
    if native['workbook_sha256']!=digest(ROOT/'fixtures/workbooks/data-entry/order-entry.xlsm'):
        raise ValueError('Original workbook changed')
    if len(native['cases'])!=2 or {case['zoom'] for case in native['cases']}!={100,150}:
        raise ValueError('Both native scales are required')
    rows=[]
    for case in native['cases']:
        if case['observations']!=actual['observations'] or len(case['observations'])!=11:
            raise ValueError('Full original state/trace/focus differs')
        for expected,observed in zip(case['observations'],actual['observations'],strict=True):
            for record in (expected,observed):
                if 'CALCFORMS_NATIVE_ERROR:' in record['state'] or 'CALCFORMS_NATIVE_ERROR:' in record['trace']:
                    raise ValueError('Original handler failed')
            state=dict(field.split('=',1) for field in expected['state'].split(';'))
            state.update(trace=expected['trace'],focus=expected['focus'])
            actual_state=dict(field.split('=',1) for field in observed['state'].split(';'))
            actual_state.update(trace=observed['trace'],focus=observed['focus'])
            if state.keys()!=actual_state.keys():
                raise ValueError('State field coverage differs')
            rows.extend(dict(zoom=case['zoom'],step=expected['step'],field=key,native=value,calcforms=actual_state[key],status='pass' if value==actual_state[key] else 'fail') for key,value in state.items())
    return dict(schema='calcforms.order_entry_validation_fields.v1',summary=dict(pass_count=sum(row['status']=='pass' for row in rows),fail_count=sum(row['status']=='fail' for row in rows),missing_measurements=0),checks=rows)


def validate():
    for relative,checksum in read(OUTPUT/'inputs.json').items():
        if digest(ROOT/relative)!=checksum:
            raise ValueError('Order-entry input changed: '+relative)
    generated=compare(read(NATIVE),read(OUTPUT/'runtime.json'))
    if generated!=read(OUTPUT/'comparison.json') or generated['summary']!=dict(pass_count=308,fail_count=0,missing_measurements=0):
        raise ValueError('Original validation/reuse fields regressed')
    print('Original order-entry BeforeUpdate/reuse/reload: 308 pass / 0 fail')


def build(log):
    OUTPUT.mkdir(exist_ok=False)
    actual=json.loads(next(line.split('=',1)[1] for line in log.read_text(encoding='utf-8').splitlines() if line.startswith('CALCFORMS_ORDER_VALIDATION=')))
    write(OUTPUT/'runtime.json',actual)
    write(OUTPUT/'comparison.json',compare(read(NATIVE),actual))
    paths=[NATIVE,NATIVE.with_name('observer.bas'),OUTPUT/'runtime.json',ROOT/'fixtures/workbooks/data-entry/order-entry.xlsm',ROOT/'fixtures/workbooks/data-entry/form-code.bas']
    write(OUTPUT/'inputs.json',{path.relative_to(ROOT).as_posix():digest(path) for path in paths})
    validate()


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--runtime-log',type=Path)
    args=parser.parse_args()
    if args.runtime_log:
        build(args.runtime_log)
    else:
        validate()
