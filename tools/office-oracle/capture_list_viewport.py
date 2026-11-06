"""Observe ListBox viewport boundaries in the existing owned hidden Excel."""
import argparse
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path

from layout_corpus import ROOT
from owned_excel import run_owned_excel
from probe_source import validate_probe_source

SOURCE = '''Option Explicit
Private Function ViewportState(ByVal ErrorCode As Long) As String
    Dim C As MSForms.ListBox
    Set C = LayoutSelection.Controls("Choices")
    ViewportState = "error=" & CStr(ErrorCode) & ";index=" & CStr(C.ListIndex) & ";top=" & CStr(C.TopIndex) & ";count=" & CStr(C.ListCount) & ";height=" & CStr(C.Height)
End Function
Public Function Run8ViewportPrepare(ByVal Zoom As Long) As String
    On Error GoTo Failed
    Load LayoutSelection
    LayoutSelection.Zoom = Zoom
    Dim C As MSForms.ListBox, I As Long
    Set C = LayoutSelection.Controls("Choices")
    C.Clear
    C.Height = 72
    For I = 0 To 22
        C.AddItem "Row " & CStr(I)
    Next
    C.ListIndex = 1
    C.TopIndex = 0
    LayoutSelection.Show vbModeless
    Run8ViewportPrepare = ViewportState(0)
    Exit Function
Failed:
    Run8ViewportPrepare = "CALCFORMS_NATIVE_ERROR:prepare:" & CStr(Err.Number) & ":" & Err.Description
End Function
Public Function Run8ViewportSet(ByVal Member As String, ByVal Value As Long) As String
    On Error GoTo Failed
    Dim C As MSForms.ListBox, Code As Long
    Set C = LayoutSelection.Controls("Choices")
    Select Case Member
        Case "top": C.TopIndex = Value
        Case "index": C.ListIndex = Value
        Case "height": C.Height = Value
        Case "clear": C.Clear
        Case Else: Err.Raise 5
    End Select
    Run8ViewportSet = ViewportState(0)
    Exit Function
Failed:
    Code = Err.Number
    Err.Clear
    On Error GoTo Fatal
    Run8ViewportSet = ViewportState(Code)
    Exit Function
Fatal:
    Run8ViewportSet = "CALCFORMS_NATIVE_ERROR:snapshot:" & CStr(Err.Number) & ":" & Err.Description
End Function
Public Sub Run8ViewportFinish()
    On Error GoTo Failed
    LayoutSelection.Hide
    Exit Sub
Failed:
    Err.Raise Err.Number, "Run8ViewportFinish", Err.Description
End Sub
'''


def capture(owner_path, output):
    output = output.resolve()
    if not output.is_relative_to(ROOT) or output.exists():
        raise ValueError('Use a fresh repository output directory')
    validate_probe_source(SOURCE)
    output.mkdir(parents=True)
    (output / 'observer.bas').write_text(SOURCE, encoding='utf-8', newline='\n')
    def action(excel, owner, directory):
        book = excel.Workbooks.Item('layout-corpus.xlsm')
        if Path(book.FullName).resolve() != directory / 'corpus/layout-corpus.xlsm':
            raise ValueError('Not the owned authored corpus')
        components = book.VBProject.VBComponents
        names = [components.Item(i).Name for i in range(1, components.Count + 1)]
        if 'Run8ViewportProbe' in names:
            module = components.Item('Run8ViewportProbe')
            if module.CodeModule.CountOfLines:
                module.CodeModule.DeleteLines(1, module.CodeModule.CountOfLines)
        else:
            module = components.Add(1)
            module.Name = 'Run8ViewportProbe'
        module.CodeModule.AddFromString(SOURCE)
        prefix = "'" + book.Name + "'!"
        cases = []
        def run(member, *args):
            value = excel.Run(prefix + member, *args)
            if isinstance(value, str) and 'CALCFORMS_NATIVE_ERROR:' in value:
                raise ValueError(value)
            return value
        try:
            for zoom in (100, 150):
                rows = [dict(step='initial', state=run('Run8ViewportPrepare', zoom))]
                for member, values in [('top', [-1, 0, 1, 16, 17, 22, 23, 99]), ('index', [-2, -1, 0, 1, 7, 22, 23])]:
                    for value in values:
                        run('Run8ViewportPrepare', zoom)
                        rows.append(dict(step=f'{member}_{value}', state=run('Run8ViewportSet', member, value)))
                run('Run8ViewportPrepare', zoom)
                for step, member, value in [('last', 'index', 22), ('shrink', 'height', 30),
                        ('reselect_last', 'index', 22), ('expand', 'height', 120), ('clear', 'clear', 0),
                        ('empty_top_negative', 'top', -1), ('empty_top_zero', 'top', 0), ('empty_top_large', 'top', 99),
                        ('empty_index_zero', 'index', 0)]:
                    rows.append(dict(step=step, state=run('Run8ViewportSet', member, value)))
                run('Run8ViewportPrepare', zoom)
                rows.append(dict(step='offscreen_same_index_before', state=run('Run8ViewportSet', 'top', 15)))
                rows.append(dict(step='offscreen_same_index_after', state=run('Run8ViewportSet', 'index', 1)))
                cases.append(dict(zoom=zoom, observations=rows))
        finally:
            run('Run8ViewportFinish')
        return dict(schema='calcforms.list_viewport_native.v1', captured_utc=datetime.now(timezone.utc).isoformat(),
            excel_pid=owner['excel_pid'], excel_launches=owner['excel_launches'], excel_version=excel.Version, excel_build=excel.Build,
            source_sha256=hashlib.sha256(SOURCE.encode('utf-8')).hexdigest(), input='in-process VBA public property calls; private desktop; no global input', observations=cases)
    result = run_owned_excel(owner_path, action)
    (output / 'observations.json').write_text(json.dumps(result, indent=2) + '\n', encoding='utf-8', newline='\n')
    print(json.dumps(result, indent=2))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--owner', type=Path, required=True)
    parser.add_argument('--out', type=Path, required=True)
    args = parser.parse_args()
    capture(args.owner, args.out)
