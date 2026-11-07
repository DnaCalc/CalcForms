"""Replay retained owned process and private desktop cleanup evidence."""
import json
from layout_corpus import ROOT


def validate():
    path=ROOT/'docs/evidence/W010_complete_msforms_object_model_parity/beads/oxforms-jbjp.108/cleanup-run9.json'
    data=json.loads(path.read_text(encoding='utf-8'))
    owner=data['owner']
    assert data['excel_launches']==owner['excel_launches']==owner['excel_launches_by_this_session']==1
    assert owner['closed']=='terminated_owned_handle' and owner['thread_desktop_restored'] and owner['desktop_cleanup']=='closed'
    assert not owner['cleanup_notes'] and owner['workbook_unchanged'] and data['server_exit_code']==0
    assert not data['owner_input_or_focus_used'] and not owner['interactive'] and not owner['input_desktop_switched'] and owner['security_changes']==0
    assert data['excel']['pid']==owner['excel_pid']==22924 and not data['excel']['owned_running']
    assert data['runtime_launches']==len(data['runtimes'])==32
    assert len({row['pid'] for row in data['runtimes']})==32
    assert all(not row['owned_running'] and len(row['image_sha256'])==64 and len(row['snapshot_sha256'])==64 for row in data['runtimes'])
    print('Run 9 cleanup: one Excel stopped, 32 runtime identities stopped, worker desktop restored, private desktop closed')


if __name__=='__main__':
    validate()
