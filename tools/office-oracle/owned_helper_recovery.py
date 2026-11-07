"""Create a recorded canary, hang only the helper, or recover in a fresh helper."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import time
import uuid

from layout_corpus import ROOT
from owned_excel import run_owned_excel
from probe_source import validate_probe_source

SOURCE = '''Option Explicit
Public Function RecoveryCanary() As String
    On Error GoTo Failed
    RecoveryCanary = "owned-helper-canary"
    Exit Function
Failed:
    RecoveryCanary = "CALCFORMS_NATIVE_ERROR:" & CStr(Err.Number)
End Function
'''


def code(component):
    module = component.CodeModule
    return (module.Lines(1, module.CountOfLines) if module.CountOfLines else '').replace('\r\n', '\n').strip()


def digest(text):
    return hashlib.sha256(text.encode()).hexdigest()


def execute(owner, marker, mode):
    marker = marker.resolve()
    if not marker.is_relative_to(ROOT):
        raise ValueError('Canary marker must be in the repository')
    validate_probe_source(SOURCE)

    def action(excel, proof, _):
        book = excel.Workbooks.Item('workbook-greeter.xlsm')
        if mode == 'hang':
            if marker.exists():
                raise ValueError('Do not overwrite helper ownership')
            name = 'HelperCanary_' + uuid.uuid4().hex[:12]
            originals = {book.VBProject.VBComponents.Item(i).Name: digest(code(book.VBProject.VBComponents.Item(i)))
                         for i in range(1, book.VBProject.VBComponents.Count + 1)}
            data = dict(schema='calcforms.helper_canary.v1', creator_pid=os.getpid(), excel_pid=proof['excel_pid'],
                        excel_launches=proof['excel_launches'], workbook=str(book.FullName), module=name,
                        source=SOURCE, source_sha256=digest(SOURCE.strip()), original_components=originals,
                        stage='planned', excel_visible=bool(excel.Visible))
            marker.write_text(json.dumps(data, indent=2) + '\n', encoding='utf-8', newline='\n')
            module = book.VBProject.VBComponents.Add(1)
            module.Name = name
            module.CodeModule.AddFromString(SOURCE)
            assert excel.Run("'" + book.Name + "'!" + name + '.RecoveryCanary') == 'owned-helper-canary'
            data['stage'] = 'canary-returned; helper-only hang'
            marker.write_text(json.dumps(data, indent=2) + '\n', encoding='utf-8', newline='\n')
            while True:
                time.sleep(.1)  # intentionally outside any Excel/COM call
        data = json.loads(marker.read_text(encoding='utf-8'))
        if data['excel_pid'] != proof['excel_pid'] or Path(data['workbook']).resolve() != Path(book.FullName).resolve():
            raise ValueError('Canary belongs to another process or workbook')
        if data['creator_pid'] == os.getpid():
            raise ValueError('Recovery must use a fresh helper process')
        matches = [book.VBProject.VBComponents.Item(i) for i in range(1, book.VBProject.VBComponents.Count + 1)
                   if book.VBProject.VBComponents.Item(i).Name == data['module']]
        if matches:
            module, = matches
            if module.Type != 1 or digest(code(module)) not in (data['source_sha256'], digest('')):
                raise ValueError('Canary contents differ; refusing to remove it')
            book.VBProject.VBComponents.Remove(module)
        after = {book.VBProject.VBComponents.Item(i).Name: digest(code(book.VBProject.VBComponents.Item(i)))
                 for i in range(1, book.VBProject.VBComponents.Count + 1)}
        assert after == data['original_components']
        result = dict(schema='calcforms.helper_recovery.v1', excel_pid=proof['excel_pid'],
                      excel_launches=proof['excel_launches'], creator_pid=data['creator_pid'], recovery_pid=os.getpid(),
                      canary_removed=not any(name == data['module'] for name in after), original_components_unchanged=True,
                      excel_visible=bool(excel.Visible), excel_version=str(excel.Version), excel_build=str(excel.Build))
        marker.with_name('recovery.json').write_text(json.dumps(result, indent=2) + '\n', encoding='utf-8', newline='\n')
        return result

    return run_owned_excel(owner, action)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--owner', required=True, type=Path)
    parser.add_argument('--marker', required=True, type=Path)
    parser.add_argument('--mode', choices=('hang', 'recover'), required=True)
    args = parser.parse_args()
    print(json.dumps(execute(args.owner, args.marker, args.mode)))
