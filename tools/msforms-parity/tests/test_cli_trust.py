"""Adversarial tests for parity-ledger CLI path and authority boundaries."""

from __future__ import annotations

import contextlib
import io
import json
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock


REPO_ROOT = Path(__file__).resolve().parents[3]
TOOL_ROOT = REPO_ROOT / "tools" / "msforms-parity"
if str(TOOL_ROOT) not in sys.path:
    sys.path.insert(0, str(TOOL_ROOT))

import cli_trust  # noqa: E402
import export_parity_ledger as export_cli  # noqa: E402
import parity_ledger  # noqa: E402
import validate_parity_ledger as validate_cli  # noqa: E402


class CliPathPolicyTests(unittest.TestCase):
    def test_export_override_cannot_name_an_arbitrary_repo_file(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            repo_root = Path(temporary).resolve()
            reviewed = cli_trust.select_export_path(
                repo_root,
                cli_trust.REVIEWED_ARTIFACT_PATH,
                Path(cli_trust.REVIEWED_ARTIFACT_PATH),
            )
            self.assertEqual(
                repo_root / Path(cli_trust.REVIEWED_ARTIFACT_PATH), reviewed
            )
            with self.assertRaisesRegex(
                parity_ledger.LedgerError, "only name the reviewed"
            ):
                cli_trust.select_export_path(
                    repo_root,
                    cli_trust.REVIEWED_ARTIFACT_PATH,
                    Path("tools/Run-EvidenceChecks.ps1"),
                )

    def test_manifest_cannot_redirect_the_reviewed_artifact(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            with self.assertRaisesRegex(
                parity_ledger.LedgerError, "does not name the reviewed"
            ):
                cli_trust.reviewed_artifact_path(
                    Path(temporary).resolve(), "docs/evidence/substitute.json"
                )

    def test_atomic_export_does_not_modify_a_hard_link_peer(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            repo_root = Path(temporary).resolve()
            peer = repo_root / "do-not-modify.txt"
            peer.write_bytes(b"sentinel")
            reviewed = repo_root / Path(cli_trust.REVIEWED_ARTIFACT_PATH)
            reviewed.parent.mkdir(parents=True)
            reviewed.hardlink_to(peer)

            written = cli_trust.write_reviewed_artifact(
                repo_root, cli_trust.REVIEWED_ARTIFACT_PATH, b"reviewed\n"
            )

            self.assertEqual(reviewed, written)
            self.assertEqual(b"reviewed\n", reviewed.read_bytes())
            self.assertEqual(b"sentinel", peer.read_bytes())

    def test_validation_list_always_starts_with_reviewed_artifact(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            repo_root = Path(temporary).resolve()
            additional = repo_root / "scratch" / "copy.json"
            paths = cli_trust.validation_paths(
                repo_root, cli_trust.REVIEWED_ARTIFACT_PATH, additional
            )
            self.assertEqual(
                repo_root / Path(cli_trust.REVIEWED_ARTIFACT_PATH), paths[0]
            )
            self.assertEqual(additional, paths[1])

    def test_additional_validation_path_cannot_escape_repo(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            repo_root = Path(temporary).resolve()
            outside = repo_root.parent / "outside-ledger.json"
            with self.assertRaisesRegex(
                parity_ledger.LedgerError, "must remain inside"
            ):
                cli_trust.validation_paths(
                    repo_root, cli_trust.REVIEWED_ARTIFACT_PATH, outside
                )


class ValidatorAuthorityOrderTests(unittest.TestCase):
    def _make_fixture(
        self, root: Path, reviewed_contents: bytes | None
    ) -> tuple[Path, Path, Path]:
        expected_path = root / "tools/msforms-parity/expected_ledger.v1.json"
        expected_path.parent.mkdir(parents=True)
        expected_path.write_text(
            json.dumps({"artifact_path": cli_trust.REVIEWED_ARTIFACT_PATH}) + "\n",
            encoding="utf-8",
        )
        reviewed_path = root / Path(cli_trust.REVIEWED_ARTIFACT_PATH)
        reviewed_path.parent.mkdir(parents=True)
        if reviewed_contents is not None:
            reviewed_path.write_bytes(reviewed_contents)
        additional_path = root / "scratch/additional.json"
        additional_path.parent.mkdir(parents=True)
        additional_path.write_text("{}\n", encoding="utf-8")
        return expected_path, reviewed_path, additional_path

    def _run_validator(self, repo_root: Path, additional_path: Path) -> int:
        argv = [
            "validate_parity_ledger.py",
            "--repo-root",
            str(repo_root),
            "--additional-ledger",
            str(additional_path),
        ]
        with mock.patch.object(sys, "argv", argv), contextlib.redirect_stderr(
            io.StringIO()
        ), contextlib.redirect_stdout(io.StringIO()):
            return validate_cli.main()

    def test_valid_alternate_cannot_bypass_missing_or_corrupt_reviewed_artifact(
        self,
    ) -> None:
        for label, contents in (("missing", None), ("corrupt", b"{not-json\n")):
            with self.subTest(label=label), tempfile.TemporaryDirectory() as temporary:
                root = Path(temporary).resolve()
                _, reviewed, additional = self._make_fixture(root, contents)
                calls: list[Path] = []

                def recording_load(path: Path) -> dict[str, object]:
                    calls.append(Path(path))
                    return parity_ledger.load_json_strict(path)

                with mock.patch.object(
                    validate_cli, "load_json_strict", side_effect=recording_load
                ):
                    self.assertEqual(1, self._run_validator(root, additional))
                self.assertIn(reviewed, calls)
                self.assertNotIn(additional, calls)

    def test_reviewed_artifact_is_validated_before_additional_copy(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary).resolve()
            minimal_ledger = {
                "canonical_sha256": "test",
                "summary": {"rows": 0, "green": False},
            }
            expected, reviewed, additional = self._make_fixture(
                root, parity_ledger.canonical_json_bytes(minimal_ledger)
            )
            additional.write_bytes(parity_ledger.canonical_json_bytes(minimal_ledger))
            expected_manifest = parity_ledger.load_json_strict(expected)
            loaded_ledgers: list[Path] = []
            real_load = parity_ledger.load_json_strict

            def recording_load(path: Path) -> dict[str, object]:
                result = real_load(path)
                if Path(path) in {reviewed, additional}:
                    loaded_ledgers.append(Path(path))
                return result

            with mock.patch.object(
                validate_cli, "load_json_strict", side_effect=recording_load
            ), mock.patch.object(
                validate_cli, "validate_committed_ledger", return_value=[]
            ), mock.patch.object(
                validate_cli,
                "build_expected_ledger_manifest",
                return_value=expected_manifest,
            ):
                self.assertEqual(0, self._run_validator(root, additional))
            self.assertEqual([reviewed, additional], loaded_ledgers)


class ExportParserPolicyTests(unittest.TestCase):
    def test_export_cli_rejects_arbitrary_output_before_writing(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary).resolve()
            arbitrary = root / "do-not-overwrite.txt"
            arbitrary.write_text("sentinel", encoding="utf-8")
            ledger = {"canonical_sha256": "test", "summary": {"rows": 0}}
            manifest = {"artifact_path": cli_trust.REVIEWED_ARTIFACT_PATH}
            argv = [
                "export_parity_ledger.py",
                "--repo-root",
                str(root),
                "--output",
                str(arbitrary),
            ]
            with mock.patch.object(sys, "argv", argv), mock.patch.object(
                export_cli, "build_ledger", return_value=ledger
            ), mock.patch.object(
                export_cli, "validate_committed_ledger", return_value=[]
            ), mock.patch.object(
                export_cli, "build_expected_ledger_manifest", return_value=manifest
            ), contextlib.redirect_stderr(io.StringIO()):
                self.assertEqual(1, export_cli.main())
            self.assertEqual("sentinel", arbitrary.read_text(encoding="utf-8"))


if __name__ == "__main__":
    unittest.main()
