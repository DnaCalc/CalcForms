"""No-UI checks for exclusive ownership and expiry during a blocked caller."""
import json
from pathlib import Path
import tempfile
import threading
import time
import unittest
from unittest.mock import patch

import desktop_lease as lease
REAL_TIMER = threading.Timer


class ManualTimer:
    current = None

    def __init__(self, duration, callback):
        self.duration, self.callback = duration, callback
        self.cancelled = False
        ManualTimer.current = self

    def start(self):
        pass

    def cancel(self):
        self.cancelled = True


class DesktopLeaseTests(unittest.TestCase):
    def setUp(self):
        root = Path(__file__).resolve().parents[2] / 'target'
        root.mkdir(exist_ok=True)
        self.temporary = tempfile.TemporaryDirectory(dir=root)
        self.path = Path(self.temporary.name) / 'desktop.lock'
        self.patches = [patch.object(lease, 'LOCK', self.path),
                        patch.object(lease, 'check_input_time'),
                        patch.object(lease, 'lease_duration', return_value=110),
                        patch.object(lease.threading, 'Timer', ManualTimer)]
        for p in self.patches:
            p.start()

    def tearDown(self):
        for p in reversed(self.patches):
            p.stop()
        self.temporary.cleanup()

    def test_normal_release_keeps_exclusive_identity(self):
        with lease.desktop_lease('test') as guard:
            guard()
            self.assertEqual('CalcForms', json.loads(self.path.read_text())['owner'])
            self.assertEqual(110, ManualTimer.current.duration)
        self.assertFalse(self.path.exists())
        self.assertTrue(ManualTimer.current.cancelled)

    def test_live_other_lock_is_never_replaced(self):
        self.path.write_text('other worker')
        with self.assertRaisesRegex(RuntimeError, 'in use'):
            with lease.desktop_lease('test'):
                self.fail('must not acquire')
        self.assertEqual('other worker', self.path.read_text())

    def test_expiry_releases_while_body_is_still_running_and_blocks_next_action(self):
        with self.assertRaisesRegex(RuntimeError, 'deadline'):
            with lease.desktop_lease('blocked COM') as guard:
                ManualTimer.current.callback()
                self.assertFalse(self.path.exists(), 'expiry does not wait for the body to return')
                with self.assertRaisesRegex(RuntimeError, 'expired'):
                    guard()

    def test_expiry_and_finally_preserve_a_replacement_lock(self):
        with self.assertRaisesRegex(RuntimeError, 'deadline'):
            with lease.desktop_lease('test'):
                self.path.write_text('replacement worker')
                ManualTimer.current.callback()
        self.assertEqual('replacement worker', self.path.read_text())

    def test_real_timer_releases_before_the_waiting_body_returns(self):
        with patch.object(lease.threading, 'Timer', REAL_TIMER), patch.object(lease, 'lease_duration', return_value=0.02):
            with self.assertRaisesRegex(RuntimeError, 'deadline'):
                with lease.desktop_lease('blocked caller'):
                    for _ in range(100):
                        if not self.path.exists():
                            break
                        time.sleep(0.01)
                    self.assertFalse(self.path.exists())


if __name__ == '__main__':
    unittest.main()
