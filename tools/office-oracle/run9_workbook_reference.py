"""Replay all measured planner and IntegralHeight state fields, retaining failures."""
import argparse
import hashlib
import json
from pathlib import Path
from layout_corpus import ROOT

BEADS=ROOT/'docs/evidence/W010_complete_msforms_object_model_parity/beads'


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read(path):
    return json.loads(path.read_text(encoding='utf-8'))


def write(path,data):
    path.write_text(json.dumps(data,indent=2)+'\n',encoding='utf-8',newline='\n')


def report(native,actual,kind):
    checks=[]
    actual={row['step']:row for row in actual['observations']}
    for case in native['cases' if kind=='planner' else 'observations']:
        if kind=='planner':
            rows=case['observations']
            expected_steps=set(actual)
        else:
            rows=[]
            for line in case['result'].splitlines():
                step,*fields=line.split(';')
                row=dict(step=step)
                for field in fields:
                    key,value=field.split('=',1)
                    row[key]=value=='True' if key=='integral' else float(value) if key=='height' else int(value)
                rows.append(row)
            expected_steps=set(actual)
        if len(rows)!=len(actual) or {row['step'] for row in rows}!=expected_steps:
            raise ValueError('Native/runtime step coverage differs')
        for row in rows:
            step=row['step']
            expected,observed=dict(row),dict(actual[step])
            if kind=='planner':
                for record in (expected,observed):
                    state=record.pop('state')
                    record.update(dict(field.split('=',1) for field in state.split(';')))
            if expected.keys()!=observed.keys():
                raise ValueError('Measured state field coverage differs')
            for key,value in expected.items():
                if key=='step':
                    continue
                checks.append(dict(zoom=case['zoom'],step=step,field=key,native=value,calcforms=observed[key],status='pass' if value==observed[key] else 'fail'))
    passed=sum(row['status']=='pass' for row in checks)
    return dict(schema='calcforms.workbook_fields.v1',kind=kind,summary=dict(pass_count=passed,fail_count=len(checks)-passed,missing_measurements=0),checks=checks)


def validate():
    planner=BEADS/'oxforms-jbjp.126'
    integral=BEADS/'oxforms-jbjp.118'
    native=read(planner/'observations.json')
    for key,path in [('workbook_sha256','planner.xlsm'),('source_sha256','form-code.bas'),('entry_sha256','entry.bas')]:
        if native[key]!=digest(ROOT/'fixtures/workbooks/planner'/path):
            raise ValueError('Original planner input differs: '+path)
    for directory,native_path,kind in [(planner,planner/'observations.json','planner'),(integral,integral/'run9-native/observations.json','integral_height')]:
        generated=report(read(native_path),read(directory/'runtime-run9.json'),kind)
        if generated!=read(directory/'comparison-run9.json'):
            raise ValueError('Workbook comparison does not regenerate: '+kind)
        for path,checksum in read(directory/'inputs-run9.json').items():
            if digest(ROOT/path)!=checksum:
                raise ValueError('Workbook observation input changed: '+path)
        if kind=='planner' and generated['summary']!=dict(pass_count=208,fail_count=0,missing_measurements=0):
            raise ValueError('Original planner state/event/error parity regressed')
        if kind!='planner' and (generated['summary']['missing_measurements'] or not generated['summary']['fail_count']):
            raise ValueError('Keep measured IntegralHeight residuals explicit')
        print(kind+': '+json.dumps(generated['summary']))


def build(planner_log,integral_log):
    for bead,log,prefix,native_path,kind in [('126',planner_log,'CALCFORMS_PLANNER=','observations.json','planner'),('118',integral_log,'CALCFORMS_INTEGRAL_HEIGHT=','run9-native/observations.json','integral_height')]:
        directory=BEADS/('oxforms-jbjp.'+bead)
        lines=log.read_text(encoding='utf-8').splitlines()
        actual=json.loads(next(line.split('=',1)[1] for line in lines if line.startswith(prefix)))
        write(directory/'runtime-run9.json',actual)
        generated=report(read(directory/native_path),actual,kind)
        write(directory/'comparison-run9.json',generated)
        paths=[directory/native_path,directory/'runtime-run9.json']
        if bead=='126':
            paths.extend(ROOT/'fixtures/workbooks/planner'/name for name in ('planner.xlsm','form-code.bas','entry.bas','PlannerForm-qualified.frm','PlannerForm-qualified.frx'))
            paths.extend(directory/name for name in ('observer.bas','observer-fixed.bas','dialog-recovery.json'))
        else:
            paths.extend(directory/name for name in ('run9-native/observer.bas','steps-native/observer.bas','steps-native/observations.json'))
        write(directory/'inputs-run9.json',{path.relative_to(ROOT).as_posix():digest(path) for path in paths})
    validate()


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--planner-log',type=Path)
    parser.add_argument('--integral-log',type=Path)
    args=parser.parse_args()
    if args.planner_log and args.integral_log:
        build(args.planner_log,args.integral_log)
    else:
        validate()
