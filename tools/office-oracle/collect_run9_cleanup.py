"""Verify only recorded owned process identities after the oracle server exits."""
import argparse
from datetime import datetime,timezone
import hashlib
import json
from pathlib import Path
import win32api
import win32con
import win32process
from layout_corpus import ROOT
from workbook_comparison_session import EXCEL

OUTPUT=ROOT/'docs/evidence/W010_complete_msforms_object_model_parity/beads/oxforms-jbjp.108/cleanup-run9.json'


def identity(pid,expected,created=None):
    try:
        process=win32api.OpenProcess(win32con.PROCESS_QUERY_INFORMATION|win32con.PROCESS_VM_READ,False,pid)
    except win32api.error as error:
        if error.winerror==87:
            return dict(pid_in_use=False,matches_owned_image=False,owned_running=False)
        raise
    try:
        path=Path(win32process.GetModuleFileNameEx(process,0)).resolve()
        matches=path==expected.resolve()
        if created is not None:
            matches=matches and abs(win32process.GetProcessTimes(process)['CreationTime'].timestamp()-created)<10
        return dict(pid_in_use=True,matches_owned_image=matches,owned_running=matches and win32process.GetExitCodeProcess(process)==259)
    finally:
        process.Close()


def collect(session):
    session=session.resolve()
    if not session.is_relative_to(ROOT) or OUTPUT.exists():
        raise ValueError('Use the owned repository session and a fresh cleanup report')
    owner_path=session/'ownership.json'
    owner=json.loads(owner_path.read_text(encoding='utf-8'))
    if owner['closed']!='terminated_owned_handle' or owner['cleanup_notes'] or not owner['thread_desktop_restored'] or owner['desktop_cleanup']!='closed':
        raise ValueError('Owned server did not close its handles and private desktop cleanly')
    commands=[json.loads(line) for line in (session/'commands.jsonl').read_text(encoding='utf-8').splitlines() if line.strip()]
    pairs=[item for item in commands if item['command']=='pair']
    runtimes=[]
    for path in sorted(session.glob('*/comparison.json')):
        row=json.loads(path.read_text(encoding='utf-8'))
        name='calcforms-workbook.exe' if row['form']=='greeter' else 'layout_probe.exe'
        image=session/'bin'/row['runtime_sha256'][:16]/name
        if hashlib.sha256(image.read_bytes()).hexdigest()!=row['runtime_sha256']:
            raise ValueError('Owned runtime image digest changed')
        pid=row['calcforms']['geometry']['pid']
        runtimes.append(dict(pid=pid,form=row['form'],zoom=row['zoom'],image_sha256=row['runtime_sha256'],
                             snapshot_sha256=hashlib.sha256(path.read_bytes()).hexdigest(),**identity(pid,image)))
    if len(runtimes)!=len(pairs) or len({row['pid'] for row in runtimes})!=len(pairs):
        raise ValueError('Recorded runtime launches and snapshot identities differ')
    excel=dict(pid=owner['excel_pid'],**identity(owner['excel_pid'],EXCEL,owner_path.stat().st_birthtime))
    if excel['owned_running'] or any(row['owned_running'] for row in runtimes):
        raise ValueError('An owned process is still running')
    result=dict(schema='calcforms.run9_cleanup.v1',verified_utc=datetime.now(timezone.utc).isoformat(),
                owner=owner,excel_launches=owner['excel_launches'],runtime_launches=len(pairs),excel=excel,runtimes=runtimes,
                server_exit_code=0,owner_input_or_focus_used=False,
                stop_method='server retained process handles; liveness verified against owned image identity',
                command_sha256=hashlib.sha256((session/'commands.jsonl').read_bytes()).hexdigest())
    OUTPUT.write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8',newline='\n')
    print('One owned Excel and '+str(len(pairs))+' owned runtime processes stopped; private desktop closed')


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--session',required=True,type=Path)
    collect(parser.parse_args().session)
