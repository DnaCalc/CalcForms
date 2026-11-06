"""Capture public native drawing output in the existing hidden owned Excel."""
import argparse
import json
from pathlib import Path

from native_drawing import observation
from owned_excel import run_owned_excel
from probe_source import validate_probe_source
from forms_parity import TEXTLESS

SOURCE = Path(__file__).with_name('native_drawing.bas').read_text(encoding='utf-8')


def install(book):
    validate_probe_source(SOURCE)
    names = [book.VBProject.VBComponents.Item(i).Name for i in range(1, book.VBProject.VBComponents.Count + 1)]
    if 'NativeDrawingObserver' in names:
        raise ValueError('Native drawing observer already installed')
    module = book.VBProject.VBComponents.Add(1)
    module.Name = 'NativeDrawingObserver'
    module.CodeModule.AddFromString(SOURCE)


def capture_controls(excel, prefix, row, directory):
    width, height = map(float, row['excel_facts'].splitlines()[0].split(';')[:2])
    size = row['excel']['geometry']['client_size']
    results = {}
    for control in row['measurements']['controls']:
        if control['native']['kind'] in TEXTLESS:
            continue
        name = control['name']
        if any(not part.isascii() or not part.isidentifier() for part in name.split('.')):
            raise ValueError('Invalid native control path')
        target = directory / (name + '-native.emf')
        if target.exists():
            raise ValueError('Do not overwrite native control drawing')
        w, h = control['native']['bounds'][2:]
        result = excel.Run(prefix + 'LayoutDrawControl', name, str(target), round(w * size[0] / width), round(h * size[1] / height))
        if result != 'ok':
            raise RuntimeError(result)
        results[name] = observation(target)
    return results


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--owner', required=True, type=Path)
    parser.add_argument('--prepare', action='store_true')
    parser.add_argument('--comparison', type=Path)
    args = parser.parse_args()
    if args.prepare == bool(args.comparison):
        parser.error('Choose --prepare or --comparison')

    def action(excel, owner, directory):
        if args.prepare:
            for name in ('workbook-greeter.xlsm', 'layout-corpus.xlsm'):
                install(excel.Workbooks.Item(name))
            return dict(prepared=True, excel_pid=owner['excel_pid'], additional_excel_launches=0)
        path = args.comparison.resolve()
        if not path.is_relative_to(directory):
            raise ValueError('Comparison must belong to this owned session')
        row = json.loads(path.read_text(encoding='utf-8'))
        name = 'workbook-greeter.xlsm' if row['form'] == 'greeter' else 'layout-corpus.xlsm'
        target = path.with_name('native-drawing.emf')
        if target.exists():
            raise ValueError('Do not overwrite a native drawing capture')
        width, height = row['excel']['geometry']['client_size']
        result = excel.Run("'" + name + "'!LayoutDraw", str(target), width, height)
        if result != 'ok':
            raise RuntimeError(result)
        data = observation(target)
        data.update(excel_pid=owner['excel_pid'], additional_excel_launches=0, client_size=[width, height])
        target.with_suffix('.json').write_text(json.dumps(data, indent=2) + '\n', encoding='utf-8', newline='\n')
        return dict(text_records=len(data['text']), path=str(target))

    print(json.dumps(run_owned_excel(args.owner, action)))


if __name__ == '__main__':
    main()
