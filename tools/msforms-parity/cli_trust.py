"""Path policy shared by the MSForms parity-ledger command-line tools."""

from __future__ import annotations

import os
import tempfile
from pathlib import Path

from parity_ledger import LedgerError


REVIEWED_ARTIFACT_PATH = (
    "docs/evidence/W010_complete_msforms_object_model_parity/beads/"
    "oxforms-jbjp.73/msforms_parity_ledger.v1.json"
)


def _lexical_absolute(repo_root: Path, requested: Path) -> Path:
    candidate = requested if requested.is_absolute() else repo_root / requested
    return Path(os.path.abspath(candidate))


def _same_path(left: Path, right: Path) -> bool:
    return os.path.normcase(str(left)) == os.path.normcase(str(right))


def reviewed_artifact_path(repo_root: Path, manifest_path: object) -> Path:
    """Return the one reviewed artifact path, rejecting redirects and drift."""

    repo_root = repo_root.resolve()
    if manifest_path != REVIEWED_ARTIFACT_PATH:
        raise LedgerError(
            "expected-ledger manifest does not name the reviewed artifact path"
        )
    artifact = _lexical_absolute(repo_root, Path(REVIEWED_ARTIFACT_PATH))
    try:
        artifact.relative_to(repo_root)
    except ValueError as exc:  # pragma: no cover - constant-path defense in depth
        raise LedgerError("reviewed artifact path escapes the repository") from exc

    # Refuse existing symlink/junction redirects, including redirects to another
    # in-repository file. The exporter must only ever write the literal reviewed
    # evidence path.
    resolved = artifact.resolve(strict=False)
    if not _same_path(resolved, artifact):
        raise LedgerError("reviewed artifact path contains a filesystem redirect")
    return artifact


def select_export_path(
    repo_root: Path, manifest_path: object, requested: Path | None
) -> Path:
    """Allow an output override only when it spells the reviewed artifact path."""

    repo_root = repo_root.resolve()
    artifact = reviewed_artifact_path(repo_root, manifest_path)
    if requested is None:
        return artifact
    candidate = _lexical_absolute(repo_root, requested)
    if not _same_path(candidate, artifact):
        raise LedgerError(
            "--output may only name the reviewed committed parity-ledger artifact"
        )
    return artifact


def write_reviewed_artifact(
    repo_root: Path, manifest_path: object, content: bytes
) -> Path:
    """Atomically replace the reviewed path without modifying a hard-link peer."""

    artifact = reviewed_artifact_path(repo_root, manifest_path)
    artifact.parent.mkdir(parents=True, exist_ok=True)
    # Recheck after directory creation so a pre-existing redirect cannot be used
    # as an exporter destination.
    artifact = reviewed_artifact_path(repo_root, manifest_path)
    temporary_name: str | None = None
    try:
        with tempfile.NamedTemporaryFile(
            mode="wb",
            dir=artifact.parent,
            prefix=f".{artifact.name}.",
            suffix=".tmp",
            delete=False,
        ) as temporary:
            temporary_name = temporary.name
            temporary.write(content)
            temporary.flush()
            os.fsync(temporary.fileno())
        os.replace(temporary_name, artifact)
        temporary_name = None
    finally:
        if temporary_name is not None:
            Path(temporary_name).unlink(missing_ok=True)
    return artifact


def validation_paths(
    repo_root: Path, manifest_path: object, additional: Path | None
) -> list[Path]:
    """Return the mandatory reviewed artifact first and an optional extra second."""

    repo_root = repo_root.resolve()
    artifact = reviewed_artifact_path(repo_root, manifest_path)
    if additional is None:
        return [artifact]

    candidate = _lexical_absolute(repo_root, additional).resolve(strict=False)
    try:
        candidate.relative_to(repo_root)
    except ValueError as exc:
        raise LedgerError("additional ledger must remain inside the repository") from exc
    if _same_path(candidate, artifact):
        return [artifact]
    return [artifact, candidate]
