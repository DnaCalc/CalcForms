"""Round 13d native probes: Enter/Exit/BeforeUpdate/AfterUpdate when focus moves by posted Tab keys (.124).

Programmatic SetFocus raises no Enter or Exit even when the form is the thread's active window (13c),
so focus is moved the way a keyboard moves it: posted WM_KEYDOWN/WM_KEYUP for Tab to the focused window
of the owned Excel on the private desktop, and posted WM_CHAR for typed text. No cursor, real keyboard or
foreground-window call of the owner's desktop is involved.
"""
import argparse
import json
import time
from pathlib import Path

from hidden_excel import hidden_excel

LOG_MODULE = """Option Explicit
Public Function PLog() As String
    PLog = InputForm.Log
    InputForm.Log = ""
End Function
Public Function PText2(ByVal Name As String) As String
    PText2 = InputForm.Controls(Name).Text
End Function
"""


def post_char(root, pid, text):
    import pythoncom
    import win32con
    import win32gui
    from native_accessibility import focused_hwnd
    for ch in text:
        target = focused_hwnd(root, pid)
        win32gui.PostMessage(target, win32con.WM_CHAR, ord(ch), 1)
        time.sleep(.05)
        pythoncom.PumpWaitingMessages()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, required=True)
    parser.add_argument('--out', type=Path, required=True)
    args = parser.parse_args()
    from capture_focus_updates import MODULE as FOCUS_MODULE
    from capture_round12_native import INPUT_FORM
    from capture_round13b_native import ACTIVATE_MODULE
    result = dict(schema='calcforms.round13d_native.v1', excel_launches=1, scenarios={}, errors={})
    try:
        with hidden_excel(args.root) as (excel, pid):
            result.update(excel_pid=pid, excel_version=str(excel.Version), excel_build=str(excel.Build))
            import win32gui
            from native_accessibility import post_key
            from workbook_comparison_session import windows
            book = excel.Workbooks.Add()
            project = book.VBProject
            form = project.VBComponents.Add(3)
            form.Name = 'InputForm'
            form.CodeModule.AddFromString(INPUT_FORM)
            for name, code in (('FocusProbe', FOCUS_MODULE), ('LogProbe', LOG_MODULE), ('Activator', ACTIVATE_MODULE)):
                mod = project.VBComponents.Add(1)
                mod.Name = name
                mod.CodeModule.AddFromString(code)
            macro = lambda name, *a: str(excel.Run("'" + book.Name + "'!" + name, *a))

            def start(prelude=()):
                macro('PLoad')
                for step in prelude:
                    macro(*step)
                macro('PShow')
                root = windows(pid, class_name='ThunderDFrame')[0]
                macro('ActivateForm', win32gui.GetWindowText(root))
                return root

            def tab(root):
                post_key(root, pid, 9)
                time.sleep(.1)
                return macro('PLog')

            scenarios = {}

            def run(name, fn):
                try:
                    root = start(fn.prelude if hasattr(fn, 'prelude') else ())
                    rows = fn(root)
                    macro('PUnload')
                    result['scenarios'][name] = rows
                    print(name, json.dumps(rows), flush=True)
                except Exception as error:
                    result['errors'][name] = repr(error)
                    try:
                        macro('PUnload')
                    except Exception:
                        pass

            def tab_only(root):
                rows = [('after-show-activate', macro('PLog')), ('focus-qty-prog', macro('PFocus', 'Qty'))]
                rows += [('tab', tab(root)), ('tab', tab(root)), ('tab', tab(root))]
                return rows

            def text_then_tab(root):
                rows = [('focus-qty-prog', macro('PFocus', 'Qty')), ('text-prog-6', macro('PText', 'Qty', '6'))]
                rows += [('tab', tab(root)), ('tab', tab(root))]
                return rows

            def typed_then_tab(root):
                rows = [('focus-qty-prog', macro('PFocus', 'Qty'))]
                post_char(root, pid, '7')
                rows.append(('typed-7', macro('PLog')))
                rows.append(('text-now', macro('PText2', 'Qty')))
                rows += [('tab', tab(root)), ('tab', tab(root))]
                return rows

            def typed_same_as_prog(root):
                rows = [('focus-qty-prog', macro('PFocus', 'Qty')), ('text-prog-8', macro('PText', 'Qty', '8'))]
                post_char(root, pid, '9')
                rows.append(('typed-9', macro('PLog')))
                rows += [('tab', tab(root)), ('tab', tab(root))]
                return rows

            def text_before_show(root):
                rows = [('after-show-activate', macro('PLog'))]
                rows += [('tab', tab(root)), ('tab', tab(root)), ('tab', tab(root))]
                return rows
            text_before_show.prelude = (('PText', 'Qty', '5'),)

            for name, fn in (('tab-only', tab_only), ('text-then-tab', text_then_tab), ('typed-then-tab', typed_then_tab),
                             ('typed-after-prog-text', typed_same_as_prog), ('text-before-show-tab', text_before_show)):
                run(name, fn)
            book.Close(False)
    finally:
        args.out.write_text(json.dumps(result, indent=2, default=str) + '\n', encoding='utf-8')


if __name__ == '__main__':
    main()
