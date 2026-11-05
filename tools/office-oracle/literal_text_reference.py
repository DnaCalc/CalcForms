"""Replay literal text/ampersand evidence; never start Office or inject input."""
import json
from pathlib import Path

from forms_parity import replay
from layout_corpus import ROOT

DIRECTORY = ROOT / 'docs/evidence/W010_complete_msforms_object_model_parity/beads/oxforms-jbjp.90'
TEXT = 'A&B && C&'
SOURCES = {'LayoutCommon': {'Prompt': [TEXT], 'InputName': [TEXT], 'Greet': [TEXT]},
           'LayoutSelection': {'Unchecked': [TEXT], 'OptionOne': [TEXT], 'ToggleOff': [TEXT],
                               'Choices': ['A&B', 'A&&B', 'tail&'], 'Dropdown': ['A&&B']}}


def run_id(text):
    # The unadorned key's frozen encoding: font 1, 8.25pt, no wrap/accelerator.
    value = 0xcbf29ce484222325
    for byte in (1).to_bytes(8, 'little') + (8250).to_bytes(4, 'little') + b'\0' + text.encode('utf-8'):
        value = ((value ^ byte) * 0x100000001b3) & 0xffffffffffffffff
    return str(value)


def measurements(row):
    result = {}
    for name, texts in SOURCES[row['form']].items():
        result[name] = []
        for text in texts:
            run = row['retained_text'].get(run_id(text))
            result[name].append(dict(native=text, calcforms=run['source'] if run else None))
    return result


def main():
    for stage in ('before', 'after'):
        path = DIRECTORY / stage / 'comparison.json'
        data = json.loads(path.read_text(encoding='utf-8'))
        report = replay(path)
        assert {(r['form'], r['zoom']) for r in report['observations']} == {
            (form, zoom) for form in SOURCES for zoom in (100, 150)}
        changed = 0
        for row in data['observations']:
            assert row['text_sources'] == SOURCES[row['form']]
            assert row['literal_text_measurements'] == measurements(row)
            for rows in row['literal_text_measurements'].values():
                for item in rows:
                    changed += item['native'] != item['calcforms']
                    if stage == 'after':
                        assert item['native'] == item['calcforms'], item
        assert (changed > 0) == (stage == 'before')
        assert report == json.loads(path.with_name('forms-parity.json').read_text(encoding='utf-8'))
    native = json.loads((DIRECTORY / 'accelerator-property.json').read_text(encoding='utf-8'))
    assert native['additional_launches'] == 0 and native['excel_pid'] == 23192
    assert [(r['value'], r['result'], r['error']) for r in native['observations']] == [
        ('b', 'b', None), ('BC', 'B', None), ('&', '&', None), ('', '', None)]
    print('Literal text: two forms/both scales preserve every ampersand; native accelerator property is separate.')


if __name__ == '__main__':
    main()
