"""Choose a captured image; never paint expected colors into a reference."""

from forms_parity import dotted_rectangle, ink_geometry


def text_samples(image, probes):
    samples = []
    for probe in probes:
        roi = probe['roi_px']
        focus = dotted_rectangle(image, roi)
        ink = ink_geometry(image, roi, probe.get('disabled', False), focus, probe['font_height_px'])
        samples.append({'control': probe['control'], **ink,
                        'matches': ink['ink_bounds_px'] is not None and ink['ink_pixels'] > 0})
    return samples


def choose_capture(composite, parent, probes, text_probes=None):
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
        if text_probes is not None:
            text = text_samples(image, text_probes)
            results[name]['text_samples'] = text
            results[name]['matches'] &= all(s['matches'] for s in text)
    selected = next((n for n in ('composite', 'parent') if results[n]['matches']), None)
    result = {'verified': selected is not None, 'selected': selected,
            'scope': ('live backgrounds at empty authored MultiPage centers and Frame corners'
                      if any(p.get('kind') == 'Frame' for p in probes) else
                      'live background at the center of an empty authored MultiPage'),
            'probes': probes, 'candidates': results}
    if text_probes is not None:
        result['text_probes'] = text_probes
        result['scope'] = 'recorded background probes and visible nonempty root text regions'
        result['text_scope'] = 'visible nonempty root text regions; presence only, not complete glyph identity or nested coverage'
    return result
