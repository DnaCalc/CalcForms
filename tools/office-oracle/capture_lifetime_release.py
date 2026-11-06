"""Measure held form/control releases in the existing hidden Excel process."""
import argparse
import hashlib
import json
from pathlib import Path

from layout_corpus import ROOT
from owned_excel import run_owned_excel
from probe_source import validate_probe_source
from workbook_comparison_session import WORKBOOK

SOURCE = '''Option Explicit
Public LifeInitialized As Long
Public LifeTerminated As Long
Private Function Counts(ByVal StepName As String) As String
    Counts = StepName & ";initialize=" & CStr(LifeInitialized) & ";terminate=" & CStr(LifeTerminated) & vbLf
End Function
Public Function ObserveRelease() As String
    On Error GoTo Failed
    Dim F As WorkbookGreeter, G As WorkbookGreeter, C As MSForms.TextBox
    Dim S As String, N As Long
    Unload WorkbookGreeter
    LifeInitialized = 0
    LifeTerminated = 0
    Set F = New WorkbookGreeter
    S = Counts("explicit-new")
    Unload F
    S = S & Counts("explicit-unload")
    Set F = Nothing
    S = S & Counts("explicit-release")
    Set F = WorkbookGreeter
    S = S & Counts("default-created")
    Set G = WorkbookGreeter
    S = S & "same-default=" & CStr(F Is G) & vbLf
    Unload F
    S = S & Counts("default-unload-held")
    Set G = Nothing
    S = S & Counts("one-form-held")
    Set F = Nothing
    S = S & Counts("last-form-release")
    Set F = WorkbookGreeter
    Set C = F.InputName
    C.Text = "retained-control"
    S = S & Counts("control-held")
    Unload F
    S = S & Counts("control-unload")
    On Error Resume Next
    Err.Clear
    S = S & "old-control-text=" & C.Text & ";error=" & CStr(Err.Number) & vbLf
    Err.Clear
    C.Text = "after-unload"
    N = Err.Number
    S = S & "old-control-write-error=" & CStr(N) & vbLf
    On Error GoTo Failed
    Set F = Nothing
    S = S & Counts("only-control-held")
    Set C = Nothing
    S = S & Counts("last-control-release")
    ObserveRelease = S
    Exit Function
Failed:
    ObserveRelease = "CALCFORMS_NATIVE_ERROR:" & CStr(Err.Number) & ":" & Err.Description & vbLf & S
End Function
'''


def capture(owner, output):
    output = output.resolve()
    if not output.is_relative_to(ROOT) or output.exists():
        raise ValueError('Use a fresh repo-local evidence directory')
    output.mkdir(parents=True)
    validate_probe_source(SOURCE)
    (output / 'observer.bas').write_text(SOURCE, encoding='utf-8', newline='\n')

    def action(excel, proof, _):
        book = excel.Workbooks.Item(WORKBOOK.name)
        form = book.VBProject.VBComponents.Item('WorkbookGreeter').CodeModule
        original = form.Lines(1, form.CountOfLines)
        instrumented = original.replace('mLog = "Initialize"', 'mLog = "Initialize"\r\n    LifeInitialized = LifeInitialized + 1')
        instrumented += '\r\nPrivate Sub UserForm_Terminate()\r\n    LifeTerminated = LifeTerminated + 1\r\nEnd Sub\r\n'
        (output / 'instrumented-form.bas').write_text(instrumented.replace('\r\n', '\n'), encoding='utf-8', newline='\n')
        module = book.VBProject.VBComponents.Add(1)
        module.Name = 'ReleaseObserver'
        try:
            module.CodeModule.AddFromString(SOURCE)
            form.DeleteLines(1, form.CountOfLines)
            form.AddFromString(instrumented)
            result = excel.Run("'" + book.Name + "'!ObserveRelease")
            return dict(schema='calcforms.native_release.v1', owner=proof, result=result,
                        workbook_sha256=hashlib.sha256(WORKBOOK.read_bytes()).hexdigest(),
                        source_sha256=hashlib.sha256(SOURCE.encode()).hexdigest())
        finally:
            form.DeleteLines(1, form.CountOfLines)
            form.AddFromString(original)
            book.VBProject.VBComponents.Remove(module)

    data = run_owned_excel(owner, action)
    (output / 'observations.json').write_text(json.dumps(data, indent=2) + '\n', encoding='utf-8', newline='\n')
    print(data['result'])
    if str(data['result']).startswith('CALCFORMS_NATIVE_ERROR:'):
        raise RuntimeError('Native release probe failed; retained as diagnostics')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--owner', type=Path, required=True)
    parser.add_argument('--out', type=Path, required=True)
    args = parser.parse_args()
    capture(args.owner, args.out)
