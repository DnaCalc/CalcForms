"""Observe original real-workbook handlers in the already-owned hidden Excel."""
import argparse
import hashlib
import json
from pathlib import Path

from layout_corpus import ROOT
from native_accessibility import accessible, post_key
from owned_excel import run_owned_excel
from probe_source import validate_probe_source
from workbook_comparison_session import windows

WORKBOOK = ROOT / 'fixtures/workbooks/data-entry/order-entry.xlsm'
SOURCE = '''Option Explicit
Public Sub OrderObserverReset()
    On Error GoTo Failed
    Unload OrderEntryForm
    Exit Sub
Failed:
    Err.Raise Err.Number, "OrderObserverReset", Err.Description
End Sub
Public Function OrderObserverForm() As Object
    On Error GoTo Failed
    Set OrderObserverForm = OrderEntryForm
    Exit Function
Failed:
    Set OrderObserverForm = Nothing
End Function
'''


def capture(owner_path, output, prepared=False):
    output = output.resolve()
    if not output.is_relative_to(ROOT) or output.exists():
        raise ValueError('Use a fresh repo-local output directory')
    output.mkdir(parents=True)
    before = hashlib.sha256(WORKBOOK.read_bytes()).hexdigest()

    def action(excel, owner, directory):
        book = excel.Workbooks.Item(WORKBOOK.name) if prepared else excel.Workbooks.Open(str(WORKBOOK), 0, True)
        if Path(book.FullName).resolve() != WORKBOOK.resolve() or not book.ReadOnly:
            raise ValueError('The genuine fixture must remain read-only')
        validate_probe_source(SOURCE)
        if prepared:
            module = book.VBProject.VBComponents.Item('Run7OrderObserver')
            if module.CodeModule.Lines(1, module.CodeModule.CountOfLines).replace('\r\n', '\n').strip() != SOURCE.strip():
                raise ValueError('Existing real-workbook observer differs')
        else:
            module = book.VBProject.VBComponents.Add(1)
            module.Name = 'Run7OrderObserver'
            module.CodeModule.AddFromString(SOURCE)
        (output / 'observer.bas').write_text(SOURCE, encoding='utf-8', newline='\n')
        prefix = "'" + book.Name + "'!"
        results = []
        for zoom in (100, 150):
            excel.Run(prefix + 'OrderObserverReset')
            excel.Run(prefix + 'OpenOrderEntry')
            f = excel.Run(prefix + 'OrderObserverForm')
            w, h = f.InsideWidth, f.InsideHeight
            f.Zoom = zoom
            f.Width += w * (zoom / 100 - 1)
            f.Height += h * (zoom / 100 - 1)
            root = windows(owner['excel_pid'], 'CalcForms order entry')[0]
            initial_focus = str(f.ActiveControl.Name)
            rows = []
            def observe(step):
                state, trace = excel.Run(prefix + 'OrderEntryState'), excel.Run(prefix + 'OrderEntryTrace')
                if 'CALCFORMS_NATIVE_ERROR:' in state or 'CALCFORMS_NATIVE_ERROR:' in trace:
                    raise ValueError(state + '\n' + trace)
                rows.append(dict(step=step, state=state, trace=trace))
                (output / f'zoom-{zoom}-partial.json').write_text(json.dumps(rows, indent=2) + '\n', encoding='utf-8', newline='\n')
            observe('initial')
            if not rows[-1]['state'].startswith('name=;team=Sales;product=Bolt;') or ';saved=0;status=Ready;visible=True' not in rows[-1]['state']:
                raise ValueError('Native real-workbook scenario did not start fresh')
            post_key(root, owner['excel_pid'], 13)
            observe('invalid_save')
            if ';saved=0;status=Name is required;visible=True' not in rows[-1]['state']:
                raise ValueError('Native default Enter did not exercise empty-name validation')
            f.SetName('Ada')
            observe('name')
            f.SetTeam(1)
            observe('team')
            f.SetProduct(2)
            observe('product')
            f.ChoosePriority()
            observe('shipping')
            f.ChoosePrepaid()
            observe('payment')
            f.SelectPage(1)
            observe('review_page')
            button = accessible(f.SaveButton)
            try:
                button.invoke()
            finally:
                button.close()
            observe('valid_save')
            button = accessible(f.CancelButton)
            try:
                button.invoke()
            finally:
                button.close()
            observe('cancel')
            results.append(dict(zoom=zoom, initial_focus=initial_focus, observations=rows))
        book.Close(False)
        return dict(schema='calcforms.real_order_entry_scenarios.v1', owner=owner,
                    workbook_sha256=before, observations=results,
                    original_handlers_unchanged=True, input='original methods; initial private-window Enter; public MSAA Save/Cancel default actions after page change')

    result = run_owned_excel(owner_path, action)
    result['workbook_unchanged'] = before == hashlib.sha256(WORKBOOK.read_bytes()).hexdigest()
    if not result['workbook_unchanged']:
        raise ValueError('Original workbook bytes changed')
    (output / 'observations.json').write_text(json.dumps(result, indent=2) + '\n', encoding='utf-8', newline='\n')
    print(json.dumps(result))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--owner', type=Path, required=True)
    parser.add_argument('--out', type=Path, required=True)
    parser.add_argument('--prepared', action='store_true')
    args = parser.parse_args()
    capture(args.owner, args.out, args.prepared)
