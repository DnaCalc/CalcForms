"""Replay retained helper timeout and recovery evidence without starting Excel."""
import hashlib
import json
from pathlib import Path
from layout_corpus import ROOT

DIRECTORY=ROOT/'docs/evidence/W010_complete_msforms_object_model_parity/beads/oxforms-jbjp.108/run9-recovery-hidden'


def validate():
    read=lambda path:json.loads((DIRECTORY/path).read_text(encoding='utf-8'))
    canary,hang,recover,result=[read(path) for path in ('canary.json','hang/report.json','recover/report.json','recovery.json')]
    assert canary['stage']=='canary-returned; helper-only hang'
    assert hashlib.sha256(canary['source'].strip().encode()).hexdigest()==canary['source_sha256']
    assert all(row['excel_pid']==22924 and row['excel_launches']==1 for row in (canary,hang,recover,result))
    assert hang['timed_out'] and hang['helper_stopped'] and hang['helper_exit_code']!=0
    assert not recover['timed_out'] and recover['helper_stopped'] and recover['helper_exit_code']==0
    assert hang['helper_pid']==canary['creator_pid']==result['creator_pid']
    assert recover['helper_pid']==result['recovery_pid']!=canary['creator_pid']
    assert all(not row['pointer_keyboard_or_owner_focus_used'] and 0<row['timeout_seconds']<=300 for row in (hang,recover))
    assert result['canary_removed'] and result['original_components_unchanged'] and not result['excel_visible']
    assert not canary['excel_visible'] and len(canary['original_components'])>=4
    print('Owned helper timeout/recovery: same hidden Excel, one launch, original modules preserved')


if __name__=='__main__':
    validate()
