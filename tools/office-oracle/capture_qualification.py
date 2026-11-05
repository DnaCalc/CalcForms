"""Choose a captured image; never paint expected colors into a reference."""


def choose_capture(composite, parent, probes):
    results = {}
    for name, image in [('composite', composite), ('parent', parent)]:
        samples = []
        for probe in probes:
            x, y = probe['pixel']
            actual = list(image.getpixel((x, y))) if 0 <= x < image.width and 0 <= y < image.height else None
            samples.append({'control': probe['control'], 'pixel': [x, y],
                            'expected_rgb': probe['expected_rgb'], 'actual_rgb': actual,
                            'matches': actual == probe['expected_rgb']})
        results[name] = {'samples': samples, 'matches': all(s['matches'] for s in samples)}
    selected = next((n for n in ('composite', 'parent') if results[n]['matches']), None)
    return {'verified': selected is not None, 'selected': selected,
            'scope': 'live background at the center of an empty authored MultiPage',
            'probes': probes, 'candidates': results}
