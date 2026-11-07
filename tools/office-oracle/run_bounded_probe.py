"""Bound a CLI probe that connects to the existing owned Excel process."""
import argparse
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[2]
TOOLS = Path(__file__).resolve().parent


def run(owner_path, script, arguments, output, timeout):
    owner_path, script, output = [Path(p).resolve() for p in (owner_path, script, output)]
    owner = json.loads(owner_path.read_text(encoding='utf-8'))
    if owner.get('closed') or owner['interactive'] or owner['excel_launches'] != 1:
        raise ValueError('A live owned hidden Excel session is required')
    if script.parent != TOOLS or not script.is_file() or script == Path(__file__).resolve():
        raise ValueError('Choose a repo oracle probe script')
    if not output.is_relative_to(ROOT) or output.exists() or not 0 < timeout <= 300:
        raise ValueError('Use a fresh repo output directory and a bounded timeout')
    output.mkdir(parents=True)
    command = [sys.executable, '-u', str(script), '--owner', str(owner_path), *arguments]
    started = time.monotonic()
    report = dict(schema='calcforms.bounded_probe.v1', excel_pid=owner['excel_pid'],
                  excel_launches=owner['excel_launches'], helper_launches=1,
                  script=script.relative_to(ROOT).as_posix(), arguments=arguments,
                  started_utc=datetime.now(timezone.utc).isoformat(), timeout_seconds=timeout,
                  pointer_keyboard_or_owner_focus_used=False)
    flags = subprocess.CREATE_NO_WINDOW if os.name == 'nt' else 0
    environment = dict(os.environ, PYTHONDONTWRITEBYTECODE='1')
    with (output / 'helper-output.txt').open('wb') as log:
        with subprocess.Popen(command, cwd=ROOT, env=environment, stdin=subprocess.DEVNULL,
                              stdout=log, stderr=subprocess.STDOUT, creationflags=flags) as process:
            report['helper_pid'] = process.pid
            try:
                process.wait(timeout=timeout)
                report['timed_out'] = False
            except subprocess.TimeoutExpired:
                report['timed_out'] = True
                # Popen.kill uses its retained Windows process handle. It never
                # finds a process by name, nor signals the connected Excel.
                process.kill()
                process.wait(timeout=10)
            report['helper_exit_code'] = process.returncode
    report['elapsed_seconds'] = round(time.monotonic() - started, 3)
    report['helper_stopped'] = True
    (output / 'report.json').write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8', newline='\n')
    return report


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--owner', required=True, type=Path)
    parser.add_argument('--script', required=True, type=Path)
    parser.add_argument('--out', required=True, type=Path)
    parser.add_argument('--timeout-seconds', type=float, default=45)
    parser.add_argument('arguments', nargs=argparse.REMAINDER)
    args = parser.parse_args()
    arguments = args.arguments[1:] if args.arguments[:1] == ['--'] else args.arguments
    result = run(args.owner, args.script, arguments, args.out, args.timeout_seconds)
    print(json.dumps(result))
    sys.exit(124 if result['timed_out'] else result['helper_exit_code'])
