"""Rank control regions from captured clients; replay needs no Office or desktop."""
from __future__ import annotations

import argparse
import hashlib
import json
import math
from pathlib import Path

from PIL import Image, ImageChops, ImageStat

from layout_corpus import ROOT


def rank_controls(data, reference, actual):
    qualification = data.get('native_capture_validation', {}).get('verified')
    result = {'comparable': False, 'native_qualification': qualification,
              'scope': 'root control union bounds; regions can overlap and errors must not be added',
              'ranked': [], 'skipped': []}
    if qualification is False or not data['pixels']['comparable']:
        result['reason'] = 'native capture or whole-client comparison is unverified'
        return result
    if reference.size != actual.size:
        result['reason'] = 'client sizes differ'
        return result
    header = data['excel_facts'].splitlines()[0].split(';')
    width, height = map(float, header[:2])
    if not all(math.isfinite(v) and v > 0 for v in (width, height)):
        raise ValueError('Native form client dimensions must be finite and positive')
    sx, sy = reference.width / width, reference.height / height
    result.update(comparable=True, scale_px_per_pt=[sx, sy])
    for control in data['measurements']['controls']:
        name = control['name']
        if '.' in name:
            result['skipped'].append({'name': name, 'reason': 'native parent client origin not measured'})
            continue
        native, runtime = control['native']['bounds'], control['calcforms']['bounds']
        if not all(math.isfinite(v) for v in (*native, *runtime)) or min(native[2:], default=0) < 0 or min(runtime[2:], default=0) < 0:
            raise ValueError('Invalid control bounds: ' + name)
        left = min(native[0], runtime[0])
        top = min(native[1], runtime[1])
        right = max(native[0] + native[2], runtime[0] + runtime[2])
        bottom = max(native[1] + native[3], runtime[1] + runtime[3])
        box = [max(0, min(reference.width, math.floor(left * sx))),
               max(0, min(reference.height, math.floor(top * sy))),
               max(0, min(reference.width, math.ceil(right * sx))),
               max(0, min(reference.height, math.ceil(bottom * sy)))]
        if box[2] <= box[0] or box[3] <= box[1]:
            result['skipped'].append({'name': name, 'reason': 'outside client or empty region'})
            continue
        diff = ImageChops.difference(reference.crop(box).convert('RGB'), actual.crop(box).convert('RGB'))
        channels = diff.split()
        nonzero = ImageChops.lighter(channels[0], ImageChops.lighter(channels[1], channels[2]))
        stats = ImageStat.Stat(diff)
        count = diff.width * diff.height
        unequal = count - nonzero.histogram()[0]
        result['ranked'].append({'name': name, 'kind': control['native']['kind'], 'roi_px': box,
                                 'pixels': count, 'different_pixels': unequal,
                                 'different_fraction': unequal / count,
                                 'mean_absolute_rgb': stats.mean,
                                 'absolute_rgb_error': int(sum(stats.sum))})
    result['ranked'].sort(key=lambda r: (-r['absolute_rgb_error'], r['name']))
    return result


def replay(path):
    data = json.loads(path.read_text(encoding='utf-8-sig'))
    rows = []
    for observation in data['observations']:
        if len(observation['images']) != 2:
            raise ValueError('Expected two reference engines')
        images = []
        for engine, artifact in zip(('excel', 'calcforms'), observation['images']):
            if not artifact['file'].endswith(f'-{engine}.png'):
                raise ValueError('Reference image engine/order differs')
            image_path = path.parent / artifact['file']
            if hashlib.sha256(image_path.read_bytes()).hexdigest() != artifact['sha256']:
                raise ValueError('Reference image hash differs: ' + artifact['file'])
            images.append(Image.open(image_path).convert('RGB'))
        if len(images) != 2:
            raise ValueError('Expected two reference engines')
        rows.append({'form': observation['form'], 'zoom': observation['zoom'],
                     'control_pixels': rank_controls(observation, *images)})
    digest = hashlib.sha256(json.dumps(data, sort_keys=True, separators=(',', ':')).encode()).hexdigest()
    return {'schema': 'calcforms.control_pixel_ranking.v1', 'pixel_parity_claimed': False,
            'reference': path.resolve().relative_to(ROOT).as_posix(),
            'reference_canonical_json_sha256': digest, 'observations': rows}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--reference', type=Path, required=True, help='committed intrinsic comparison.json')
    output = parser.add_mutually_exclusive_group()
    output.add_argument('--out', type=Path)
    output.add_argument('--check', type=Path)
    args = parser.parse_args()
    result = replay(args.reference)
    if args.check:
        if result != json.loads(args.check.read_text(encoding='utf-8-sig')):
            raise ValueError('Control pixel ranking differs from recorded reference')
        print('Control pixel ranking: all recorded regions and errors recomputed.')
    elif args.out:
        args.out.write_text(json.dumps(result, indent=2) + '\n', encoding='utf-8', newline='\n')
    else:
        print(json.dumps(result, indent=2))


if __name__ == '__main__':
    main()
