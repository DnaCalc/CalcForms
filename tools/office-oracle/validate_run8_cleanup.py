"""Verify retained exact-process and private-desktop cleanup for the one-Excel run."""
import json

from layout_corpus import ROOT


def validate():
    path = ROOT / 'docs/evidence/W010_complete_msforms_object_model_parity/beads/oxforms-jbjp.108/cleanup-run8.json'
    data = json.loads(path.read_text(encoding='utf-8'))
    owner = data['owner']
    assert data['excel_launches'] == owner['excel_launches'] == owner['excel_launches_by_this_session'] == 1
    assert owner['closed'] == 'terminated_owned_handle' and owner['workbook_unchanged']
    assert owner['thread_desktop_restored'] and owner['desktop_cleanup'] == 'closed'
    assert owner['cleanup_notes'] == [] and data['server_exit_code'] == 0
    assert not data['owner_input_or_focus_used'] and not owner['interactive']
    assert not owner['input_desktop_switched'] and owner['security_changes'] == 0
    assert len(data['runtime_closed_handles']) == data['runtime_launches']
    assert len({item['pid'] for item in data['runtime_closed_handles']}) == data['runtime_launches']
    assert all(item['result'] == 'closed' for item in data['runtime_closed_handles'])
    assert str(owner['excel_pid']) in data['processes_still_running']
    assert not any(data['processes_still_running'].values())
    print('Run 8: one hidden Excel stopped by retained handle; runtimes stopped; thread desktop restored and private desktop closed.')


if __name__ == '__main__':
    validate()
