"""Mutation tests for the row-level MSForms parity ledger.

These tests deliberately distinguish local schema consistency from authority.
An internally coherent, same-count substitution can pass the structure checks;
the strict validator must still reject it by regenerating from pinned inputs.
"""

from __future__ import annotations

import copy
import json
import sys
import tempfile
import unittest
from collections import Counter
from pathlib import Path
from typing import Any, Callable


REPO_ROOT = Path(__file__).resolve().parents[3]
TOOL_ROOT = REPO_ROOT / "tools" / "msforms-parity"
if str(TOOL_ROOT) not in sys.path:
    sys.path.insert(0, str(TOOL_ROOT))

import parity_ledger as ledger_module  # noqa: E402


RowPredicate = Callable[[dict[str, Any]], bool]
_BASELINE_LEDGER: dict[str, Any] | None = None


def _baseline_ledger() -> dict[str, Any]:
    global _BASELINE_LEDGER
    if _BASELINE_LEDGER is None:
        _BASELINE_LEDGER = ledger_module.build_ledger(REPO_ROOT)
    return _BASELINE_LEDGER


def _row_index(rows: list[dict[str, Any]], predicate: RowPredicate) -> int:
    matches = [index for index, row in enumerate(rows) if predicate(row)]
    if len(matches) != 1:
        raise AssertionError(f"expected exactly one row, found {len(matches)}")
    return matches[0]


def _clone_with_row(
    ledger: dict[str, Any], predicate: RowPredicate
) -> tuple[dict[str, Any], dict[str, Any]]:
    mutated = dict(ledger)
    mutated["rows"] = list(ledger["rows"])
    index = _row_index(mutated["rows"], predicate)
    row = copy.deepcopy(mutated["rows"][index])
    mutated["rows"][index] = row
    return mutated, row


def _clone_first_with_row(
    ledger: dict[str, Any], predicate: RowPredicate
) -> tuple[dict[str, Any], dict[str, Any]]:
    mutated = dict(ledger)
    mutated["rows"] = list(ledger["rows"])
    index = next(
        (index for index, row in enumerate(mutated["rows"]) if predicate(row)), None
    )
    if index is None:
        raise AssertionError("expected at least one matching row")
    row = copy.deepcopy(mutated["rows"][index])
    mutated["rows"][index] = row
    return mutated, row


def _normalize(ledger: dict[str, Any]) -> None:
    """Rebuild all derived cells so a mutation is coherent, not a stale-hash trick."""

    for row in ledger["rows"]:
        row["row_status"] = ledger_module._row_status(row)
    source_summary = ledger["summary"]["source_surface"]
    ledger["summary"] = ledger_module._summary(ledger["rows"], source_summary)
    canonical = {
        "inputs": ledger["inputs"],
        "source_surface_sha256": ledger["source_surface_sha256"],
        "rows": ledger["rows"],
        "summary": ledger["summary"],
    }
    ledger["canonical_sha256"] = ledger_module.semantic_sha256(canonical)


def _rehash_signature(signature: dict[str, Any]) -> None:
    signature["signature_sha256"] = ledger_module.semantic_sha256(
        {key: value for key, value in signature.items() if key != "signature_sha256"}
    )


def _sync_projection_contracts(
    ledger: dict[str, Any], declaration_row: dict[str, Any]
) -> None:
    for projection_id in declaration_row.get("projection_refs", []):
        index = _row_index(
            ledger["rows"], lambda row: row["row_id"] == projection_id
        )
        projection = copy.deepcopy(ledger["rows"][index])
        ledger["rows"][index] = projection
        if projection["row_kind"] in {"surface_member", "abi_adapter_member"}:
            projection["contract"]["accessors"] = copy.deepcopy(
                declaration_row["contract"]["accessors"]
            )
        elif projection["row_kind"] in {
            "event_projection",
            "host_event_attachment",
        }:
            projection["contract"]["event_signature"] = copy.deepcopy(
                declaration_row["contract"]["accessors"]["func"]
            )


def _first_semantic_target(type_fact: dict[str, Any]) -> dict[str, Any] | None:
    target = type_fact.get("target")
    if isinstance(target, dict):
        if "name" in target and "type_index" in target:
            return target
        nested = _first_semantic_target(target)
        if nested is not None:
            return nested
    element = type_fact.get("element")
    if isinstance(element, dict):
        return _first_semantic_target(element)
    return None


class GeneratedLedgerTestCase(unittest.TestCase):
    maxDiff = None

    @classmethod
    def setUpClass(cls) -> None:
        cls.ledger = _baseline_ledger()
        validator = getattr(ledger_module, "validate_committed_ledger", None)
        cls.strict_validate = staticmethod(validator) if validator is not None else None

    def assertStructureRejected(
        self, ledger: dict[str, Any], expected_fragment: str
    ) -> None:
        errors = ledger_module.validate_ledger_structure(ledger)
        self.assertTrue(errors, "the local validator unexpectedly accepted the mutation")
        self.assertTrue(
            any(expected_fragment in error for error in errors),
            f"expected {expected_fragment!r} in {errors!r}",
        )

    def assertStrictlyRejected(self, ledger: dict[str, Any]) -> None:
        self.assertEqual(
            [],
            ledger_module.validate_ledger_structure(ledger),
            "fixture mutation must remain internally coherent so the strict check is exercised",
        )
        self.assertIsNotNone(
            self.strict_validate,
            "parity_ledger.validate_committed_ledger(repo_root, ledger) is required",
        )
        errors = self.strict_validate(REPO_ROOT, ledger)
        self.assertTrue(errors, "strict validator accepted an authoritative-ledger mutation")


class LoaderProfileAdversarialTests(unittest.TestCase):
    _HEADLESS_SOURCE = '''
fn calcforms_modules(repo_root: &Path) -> Result<Vec<ModuleUnit>, String> {
    use ModuleKind::{Class, Procedural};
    let modules = [
        ("Label", Class, "vba/calcforms/Label.cls"),
    ];
    modules
        .into_iter()
        .map(|(name, kind, path)| module_unit(repo_root, name, kind, Path::new(path)))
        .collect()
}

fn module_unit(
    repo_root: &Path,
    name: &str,
    kind: ModuleKind,
    relative_path: &Path,
) -> Result<ModuleUnit, String> {
    let path = repo_root.join(relative_path);
    let source =
        std::fs::read_to_string(&path).map_err(|err| format!("read {}: {err}", path.display()))?;
    let mut attributes = ModuleAttributes::named(name);
    attributes.vb_exposed = true;
    attributes.vb_creatable = true;
    Ok(ModuleUnit {
        module_name: name.to_string(),
        module_kind: kind,
        attributes,
        source,
    })
}
'''

    def _validate_source(self, source: str) -> None:
        source_path = "loader-profile-test.rs"
        tokens = ledger_module._rust_tokens(source, source_path)
        inventory = ledger_module._parse_headless_loader_inventory(
            tokens, source_path
        )
        if [item["name"] for item in inventory] != ["Label"]:
            raise ledger_module.LedgerError("loader profile module inventory differs")
        ledger_module._validate_loader_helper(tokens, "module_unit", source_path)

    def assertLoaderRejected(self, source: str, expected_fragment: str) -> None:
        with self.assertRaises(ledger_module.LedgerError) as caught:
            self._validate_source(source)
        self.assertIn(expected_fragment, str(caught.exception))

    def test_reviewed_live_loader_shape_is_accepted(self) -> None:
        self._validate_source(self._HEADLESS_SOURCE)

    def test_comments_cannot_supply_inventory_or_forced_attributes(self) -> None:
        comment_only_tuple = self._HEADLESS_SOURCE.replace(
            '        ("Label", Class, "vba/calcforms/Label.cls"),',
            '        // ("Label", Class, "vba/calcforms/Label.cls"),',
        )
        comment_only_assignments = self._HEADLESS_SOURCE.replace(
            "    attributes.vb_exposed = true;\n"
            "    attributes.vb_creatable = true;",
            "    /* attributes.vb_exposed = true;\n"
            "       attributes.vb_creatable = true; */",
        )
        cases = [
            (comment_only_tuple, "module inventory differs"),
            (comment_only_assignments, "does not directly force exposed+creatable"),
        ]
        for source, expected in cases:
            with self.subTest(expected=expected):
                self.assertLoaderRejected(source, expected)

    def test_dead_inventory_and_disconnected_return_mapping_are_rejected(self) -> None:
        disconnected_inventory = self._HEADLESS_SOURCE.replace(
            "    let modules = [\n"
            '        ("Label", Class, "vba/calcforms/Label.cls"),\n'
            "    ];",
            "    let dead_modules = [\n"
            '        ("Label", Class, "vba/calcforms/Label.cls"),\n'
            "    ];\n"
            "    let modules = [];",
        )
        disconnected_return = self._HEADLESS_SOURCE.replace(
            "    modules\n"
            "        .into_iter()\n"
            "        .map(|(name, kind, path)| module_unit(repo_root, name, kind, Path::new(path)))\n"
            "        .collect()",
            "    Vec::new()",
        )
        cases = [
            (disconnected_inventory, "reviewed direct array shape"),
            (disconnected_return, "does not directly map its live modules binding"),
        ]
        for source, expected in cases:
            with self.subTest(expected=expected):
                self.assertLoaderRejected(source, expected)

    def test_cfg_or_visibility_modifiers_cannot_disable_reviewed_functions(self) -> None:
        for function_name in ("calcforms_modules", "module_unit"):
            with self.subTest(function=function_name):
                mutated = self._HEADLESS_SOURCE.replace(
                    f"fn {function_name}",
                    f"#[cfg(any())]\npub fn {function_name}",
                    1,
                )
                self.assertLoaderRejected(
                    mutated, "unconditional private top-level function"
                )

    def test_bootstrap_oxforms_paths_cannot_evade_scope_by_case_or_separator(self) -> None:
        source_path = "crates/calcforms-bootstrap/src/main.rs"
        source = (REPO_ROOT / source_path).read_text(encoding="utf-8")
        original = (
            'include_str!("../../../vba/smoke/fixtures/'
            'reducer_greeter_form.cls")'
        )
        self.assertIn(original, source)
        replacements = {
            "case": 'include_str!("../../../VBA/CALCFORMS/Label.cls")',
            "backslash": (
                'include_str!(r"..\\..\\..\\VBA\\CALCFORMS\\Label.cls")'
            ),
        }
        for label, replacement in replacements.items():
            with self.subTest(label=label), self.assertRaisesRegex(
                ledger_module.LedgerError, "noncanonical .*include_str path"
            ):
                tokens = ledger_module._rust_tokens(
                    source.replace(original, replacement, 1), source_path
                )
                ledger_module._parse_bootstrap_loader_inventory(
                    tokens, source_path, REPO_ROOT
                )

    def test_loader_policy_requires_the_exact_profile_identity_set(self) -> None:
        policy = ledger_module.load_json_strict(
            TOOL_ROOT / "surface_policy.v1.json"
        )
        ledger_module._validate_loader_profiles(REPO_ROOT, policy)
        mutations = {
            "missing_clean": lambda profiles: profiles.pop(0),
            "missing_manual": lambda profiles: profiles.pop(1),
            "wrong_kind": lambda profiles: profiles[1].__setitem__(
                "kind", "project_manifest"
            ),
            "wrong_path": lambda profiles: profiles[1].__setitem__(
                "source_path", "crates/calcforms-bootstrap/src/main.rs"
            ),
            "duplicate_nonmanual": lambda profiles: profiles.append(
                copy.deepcopy(profiles[0])
            ),
        }
        for label, mutate in mutations.items():
            mutated = copy.deepcopy(policy)
            mutate(mutated["effective_loader_profiles"])
            with self.subTest(label=label), self.assertRaisesRegex(
                ledger_module.LedgerError, "loader policy|duplicate loader"
            ):
                ledger_module._validate_loader_profiles(REPO_ROOT, mutated)

    def test_manual_loader_inventory_reaches_the_bound_host_project(self) -> None:
        sources = {
            "headless_runner_forced": "crates/calcforms-headless-runner/src/lib.rs",
            "bootstrap_forced": "crates/calcforms-bootstrap/src/main.rs",
        }
        for profile_id, source_path in sources.items():
            with self.subTest(profile=profile_id):
                source = (REPO_ROOT / source_path).read_text(encoding="utf-8")
                tokens = ledger_module._rust_tokens(source, source_path)
                ledger_module._validate_loader_host_binding(
                    tokens, profile_id, source_path
                )

        mutations = {
            "headless_inventory_call": (
                "headless_runner_forced",
                sources["headless_runner_forced"],
                "let mut modules = calcforms_modules(repo_root)?;",
                "let mut modules = Vec::new();",
            ),
            "headless_manifest_binding": (
                "headless_runner_forced",
                sources["headless_runner_forced"],
                "        modules,\n        references:",
                "        modules: Vec::new(),\n        references:",
            ),
            "bootstrap_inventory_call": (
                "bootstrap_forced",
                sources["bootstrap_forced"],
                "        modules: calcforms_modules(),",
                "        modules: Vec::new(),",
            ),
            "bootstrap_shadow_manifest": (
                "bootstrap_forced",
                sources["bootstrap_forced"],
                "    let program = calcvba_bind::bind_program",
                "    let manifest = SymbolProjectManifest { modules: Vec::new(), ..manifest };\n"
                "    let program = calcvba_bind::bind_program",
            ),
            "bootstrap_entry_call": (
                "bootstrap_forced",
                sources["bootstrap_forced"],
                "let (session, surface, fonts) = build_session()?;",
                "let (session, surface, fonts) = other_session()?;",
            ),
        }
        for label, (profile_id, source_path, original, replacement) in mutations.items():
            with self.subTest(mutation=label):
                source = (REPO_ROOT / source_path).read_text(encoding="utf-8")
                self.assertIn(original, source)
                tokens = ledger_module._rust_tokens(
                    source.replace(original, replacement, 1), source_path
                )
                with self.assertRaisesRegex(
                    ledger_module.LedgerError,
                    "calcforms_modules-to-bind_program|live build_session caller|full-source token identity",
                ):
                    ledger_module._validate_loader_host_binding(
                        tokens, profile_id, source_path
                    )

        full_source_bypasses = {
            "headless_shadow_after_bind": (
                "headless_runner_forced",
                sources["headless_runner_forced"],
                "    let bundle = calcvba_oxir::elaborate::elaborate(&program)",
                "    let program = other_bound_program();\n"
                "    let bundle = calcvba_oxir::elaborate::elaborate(&program)",
            ),
            "bootstrap_shadow_after_bind": (
                "bootstrap_forced",
                sources["bootstrap_forced"],
                "    let bundle = calcvba_oxir::elaborate::elaborate(&program)",
                "    let program = other_bound_program();\n"
                "    let bundle = calcvba_oxir::elaborate::elaborate(&program)",
            ),
            "headless_wrong_impl_owner": (
                "headless_runner_forced",
                sources["headless_runner_forced"],
                "impl HeadlessRunner {",
                "impl WrongOwner {",
            ),
            "bootstrap_main_redirect": (
                "bootstrap_forced",
                sources["bootstrap_forced"],
                "    match run() {",
                "    match other_run() {",
            ),
        }
        for label, (profile_id, source_path, original, replacement) in (
            full_source_bypasses.items()
        ):
            with self.subTest(full_source_bypass=label):
                source = (REPO_ROOT / source_path).read_text(encoding="utf-8")
                self.assertIn(original, source)
                tokens = ledger_module._rust_tokens(
                    source.replace(original, replacement, 1), source_path
                )
                with self.assertRaisesRegex(
                    ledger_module.LedgerError, "full-source token identity"
                ):
                    ledger_module._validate_loader_host_binding(
                        tokens, profile_id, source_path
                    )

        for profile_id, source_path in sources.items():
            with self.subTest(crate_cfg=profile_id):
                source = (REPO_ROOT / source_path).read_text(encoding="utf-8")
                tokens = ledger_module._rust_tokens(
                    "#![cfg(any())]\n" + source, source_path
                )
                with self.assertRaisesRegex(
                    ledger_module.LedgerError, "must not crate-gate"
                ):
                    ledger_module._validate_loader_host_binding(
                        tokens, profile_id, source_path
                    )

        dead_decoys = {
            "headless_runner_forced": (
                sources["headless_runner_forced"],
                "let (session, surface) = build_session(repo_root, spec, &options)?;",
                "let (session, surface) = other_session(repo_root, spec, &options)?;",
                '''
#[cfg(any())]
fn dead_entry(repo_root: &Path, spec: &FormSpec, options: &RunnerOptions) {
    let (session, surface) = build_session(repo_root, spec, &options)?;
}
''',
            ),
            "bootstrap_forced": (
                sources["bootstrap_forced"],
                "let (session, surface, fonts) = build_session()?;",
                "let (session, surface, fonts) = other_session()?;",
                '''
#[cfg(any())]
fn dead_entry() {
    let (session, surface, fonts) = build_session()?;
}
''',
            ),
        }
        for profile_id, (source_path, live, replacement, decoy) in dead_decoys.items():
            with self.subTest(dead_decoy=profile_id):
                source = (REPO_ROOT / source_path).read_text(encoding="utf-8")
                mutated = source.replace(live, replacement, 1) + decoy
                tokens = ledger_module._rust_tokens(mutated, source_path)
                with self.assertRaisesRegex(
                    ledger_module.LedgerError, "live build_session caller"
                ):
                    ledger_module._validate_loader_host_binding(
                        tokens, profile_id, source_path
                    )

    def test_loader_tuple_identity_matches_parsed_vba_attribute_identity(self) -> None:
        inventories = {
            "manual": [
                {
                    "name": "Label",
                    "kind": "Class",
                    "path": "vba/calcforms/Label.cls",
                }
            ]
        }
        exact_surface = {
            "modules": [
                {
                    "name": "Label",
                    "file_stem": "Label",
                    "kind": "class_module",
                    "path": "vba/calcforms/Label.cls",
                }
            ]
        }
        ledger_module._validate_loader_surface_identity(
            exact_surface, inventories
        )
        for field, value in (
            ("name", "Other"),
            ("kind", "standard_module"),
            ("file_stem", "Other"),
            ("source_header_line_count", 4),
        ):
            with self.subTest(field=field):
                mutated = copy.deepcopy(exact_surface)
                mutated["modules"][0][field] = value
                with self.assertRaisesRegex(
                    ledger_module.LedgerError,
                    "tuple identity differs from parsed VBA module",
                ):
                    ledger_module._validate_loader_surface_identity(
                        mutated, inventories
                    )

    def test_loader_crates_keep_default_targets_and_workspace_membership(self) -> None:
        def make_repo(root: Path) -> None:
            (root / "crates/calcforms-headless-runner/src").mkdir(parents=True)
            (root / "crates/calcforms-bootstrap/src").mkdir(parents=True)
            (root / "crates/calcforms-calcvba-adapter/src").mkdir(parents=True)
            (root / "Cargo.toml").write_text(
                '''[workspace]
members = ["crates/calcforms-headless-runner", "crates/calcforms-bootstrap", "crates/calcforms-calcvba-adapter"]
resolver = "2"

[workspace.metadata.calcforms.calcvba_baseline]
repo = "https://github.com/DnaCalc/CalcVBA.git"
rev = "4cbe8b9c1ccc74c18dd76102b25b658cada4e625"
''',
                encoding="utf-8",
            )
            for crate, package, source in (
                ("calcforms-headless-runner", "calcforms-headless-runner", "lib.rs"),
                ("calcforms-bootstrap", "calcforms-bootstrap", "main.rs"),
            ):
                crate_root = root / "crates" / crate
                (crate_root / "Cargo.toml").write_text(
                    f'''[package]
name = "{package}"
version = "0.0.0"

[dependencies]
calcforms-calcvba-adapter = {{ path = "../calcforms-calcvba-adapter" }}
calcvba-bind = {{ git = "https://github.com/DnaCalc/CalcVBA.git", rev = "4cbe8b9c1ccc74c18dd76102b25b658cada4e625" }}
calcvba-bundle = {{ git = "https://github.com/DnaCalc/CalcVBA.git", rev = "4cbe8b9c1ccc74c18dd76102b25b658cada4e625" }}
calcvba-com = {{ git = "https://github.com/DnaCalc/CalcVBA.git", rev = "4cbe8b9c1ccc74c18dd76102b25b658cada4e625" }}
calcvba-hal = {{ git = "https://github.com/DnaCalc/CalcVBA.git", rev = "4cbe8b9c1ccc74c18dd76102b25b658cada4e625" }}
calcvba-engine = {{ git = "https://github.com/DnaCalc/CalcVBA.git", rev = "4cbe8b9c1ccc74c18dd76102b25b658cada4e625" }}
calcvba-oxir = {{ git = "https://github.com/DnaCalc/CalcVBA.git", rev = "4cbe8b9c1ccc74c18dd76102b25b658cada4e625" }}
calcvba-runtime = {{ git = "https://github.com/DnaCalc/CalcVBA.git", rev = "4cbe8b9c1ccc74c18dd76102b25b658cada4e625" }}
calcvba-symbol = {{ git = "https://github.com/DnaCalc/CalcVBA.git", rev = "4cbe8b9c1ccc74c18dd76102b25b658cada4e625" }}
''',
                    encoding="utf-8",
                )
                (crate_root / "src" / source).write_text("", encoding="utf-8")
            adapter_root = root / "crates/calcforms-calcvba-adapter"
            (adapter_root / "Cargo.toml").write_text(
                '''[package]
name = "calcforms-calcvba-adapter"
version = "0.0.0"

[dependencies]
calcvba-bind = { git = "https://github.com/DnaCalc/CalcVBA.git", rev = "4cbe8b9c1ccc74c18dd76102b25b658cada4e625" }
calcvba-hal = { git = "https://github.com/DnaCalc/CalcVBA.git", rev = "4cbe8b9c1ccc74c18dd76102b25b658cada4e625" }
calcvba-office = { git = "https://github.com/DnaCalc/CalcVBA.git", rev = "4cbe8b9c1ccc74c18dd76102b25b658cada4e625" }
calcvba-oxir = { git = "https://github.com/DnaCalc/CalcVBA.git", rev = "4cbe8b9c1ccc74c18dd76102b25b658cada4e625" }
calcvba-symbol = { git = "https://github.com/DnaCalc/CalcVBA.git", rev = "4cbe8b9c1ccc74c18dd76102b25b658cada4e625" }
calcvba-bundle = { git = "https://github.com/DnaCalc/CalcVBA.git", rev = "4cbe8b9c1ccc74c18dd76102b25b658cada4e625" }
calcvba-com = { git = "https://github.com/DnaCalc/CalcVBA.git", rev = "4cbe8b9c1ccc74c18dd76102b25b658cada4e625" }
calcvba-engine = { git = "https://github.com/DnaCalc/CalcVBA.git", rev = "4cbe8b9c1ccc74c18dd76102b25b658cada4e625" }
calcvba-runtime = { git = "https://github.com/DnaCalc/CalcVBA.git", rev = "4cbe8b9c1ccc74c18dd76102b25b658cada4e625" }
''',
                encoding="utf-8",
            )
            (adapter_root / "src/lib.rs").write_text("", encoding="utf-8")

        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            make_repo(root)
            ledger_module._validate_loader_cargo_targets(root)

        for label in (
            "alternate_lib",
            "alternate_bin",
            "missing_member",
            "excluded_member",
            "redirected_workspace",
            "typed_members",
            "typed_exclude",
            "default_run",
        ):
            with self.subTest(label=label), tempfile.TemporaryDirectory() as temporary:
                root = Path(temporary)
                make_repo(root)
                if label == "alternate_lib":
                    with (root / "crates/calcforms-headless-runner/Cargo.toml").open(
                        "a", encoding="utf-8"
                    ) as stream:
                        stream.write('\n[lib]\npath = "other.rs"\n')
                elif label == "alternate_bin":
                    with (root / "crates/calcforms-bootstrap/Cargo.toml").open(
                        "a", encoding="utf-8"
                    ) as stream:
                        stream.write('\n[[bin]]\npath = "other.rs"\n')
                elif label == "missing_member":
                    (root / "Cargo.toml").write_text(
                        '[workspace]\nmembers = ["crates/calcforms-headless-runner"]\n',
                        encoding="utf-8",
                    )
                elif label == "excluded_member":
                    (root / "Cargo.toml").write_text(
                        '''[workspace]
members = ["crates/calcforms-headless-runner", "crates/calcforms-bootstrap"]
exclude = ["crates/calcforms-bootstrap"]
''',
                        encoding="utf-8",
                    )
                elif label == "redirected_workspace":
                    path = root / "crates/calcforms-bootstrap/Cargo.toml"
                    path.write_text(
                        'workspace = "../../other-workspace"\n'
                        + path.read_text(encoding="utf-8"),
                        encoding="utf-8",
                    )
                elif label == "typed_members":
                    (root / "Cargo.toml").write_text(
                        '''[workspace]
members = ["crates/calcforms-headless-runner", "crates/calcforms-bootstrap", false]
''',
                        encoding="utf-8",
                    )
                elif label == "default_run":
                    path = root / "crates/calcforms-bootstrap/Cargo.toml"
                    source = path.read_text(encoding="utf-8")
                    path.write_text(
                        source.replace(
                            'version = "0.0.0"',
                            'version = "0.0.0"\ndefault-run = "decoy"',
                            1,
                        ),
                        encoding="utf-8",
                    )
                    decoy = root / "crates/calcforms-bootstrap/src/bin/decoy.rs"
                    decoy.parent.mkdir()
                    decoy.write_text("fn main() {}\n", encoding="utf-8")
                else:
                    (root / "Cargo.toml").write_text(
                        '''[workspace]
members = ["crates/calcforms-headless-runner", "crates/calcforms-bootstrap"]
exclude = false
''',
                        encoding="utf-8",
                    )
                with self.assertRaisesRegex(
                    ledger_module.LedgerError,
                    "default Cargo target identity|workspace omits|members are missing|reviewed CalcVBA baseline",
                ):
                    ledger_module._validate_loader_cargo_targets(root)

        revision_mutations = {
            "wrong_root_repo": (
                "Cargo.toml",
                "https://github.com/DnaCalc/CalcVBA.git",
                "https://example.invalid/CalcVBA.git",
            ),
            "wrong_root_rev": (
                "Cargo.toml",
                "4cbe8b9c1ccc74c18dd76102b25b658cada4e625",
                "0000000000000000000000000000000000000000",
            ),
            "wrong_dependency_repo": (
                "crates/calcforms-headless-runner/Cargo.toml",
                "https://github.com/DnaCalc/CalcVBA.git",
                "https://example.invalid/CalcVBA.git",
            ),
            "wrong_dependency_rev": (
                "crates/calcforms-bootstrap/Cargo.toml",
                "4cbe8b9c1ccc74c18dd76102b25b658cada4e625",
                "0000000000000000000000000000000000000000",
            ),
            "missing_dependency": (
                "crates/calcforms-bootstrap/Cargo.toml",
                'calcvba-symbol = { git = "https://github.com/DnaCalc/CalcVBA.git", rev = "4cbe8b9c1ccc74c18dd76102b25b658cada4e625" }\n',
                "",
            ),
            "wrong_adapter_rev": (
                "crates/calcforms-calcvba-adapter/Cargo.toml",
                "4cbe8b9c1ccc74c18dd76102b25b658cada4e625",
                "0000000000000000000000000000000000000000",
            ),
            "missing_adapter_dependency": (
                "crates/calcforms-calcvba-adapter/Cargo.toml",
                'calcvba-engine = { git = "https://github.com/DnaCalc/CalcVBA.git", rev = "4cbe8b9c1ccc74c18dd76102b25b658cada4e625" }\n',
                "",
            ),
            "loader_adapter_feature": (
                "crates/calcforms-headless-runner/Cargo.toml",
                'calcforms-calcvba-adapter = { path = "../calcforms-calcvba-adapter" }',
                'calcforms-calcvba-adapter = { path = "../calcforms-calcvba-adapter", features = ["alternate"] }',
            ),
            "wrong_workspace_resolver": (
                "Cargo.toml",
                'resolver = "2"',
                'resolver = "1"',
            ),
            "explicit_loader_build_script": (
                "crates/calcforms-headless-runner/Cargo.toml",
                'version = "0.0.0"',
                'version = "0.0.0"\nbuild = "decoy.rs"',
            ),
            "explicit_adapter_build_script": (
                "crates/calcforms-calcvba-adapter/Cargo.toml",
                'version = "0.0.0"',
                'version = "0.0.0"\nbuild = "decoy.rs"',
            ),
        }
        for label, (relative_path, original, replacement) in revision_mutations.items():
            with self.subTest(label=label), tempfile.TemporaryDirectory() as temporary:
                root = Path(temporary)
                make_repo(root)
                path = root / relative_path
                source = path.read_text(encoding="utf-8")
                self.assertIn(original, source)
                path.write_text(
                    source.replace(original, replacement, 1), encoding="utf-8"
                )
                with self.assertRaisesRegex(
                    ledger_module.LedgerError,
                    "reviewed CalcVBA baseline|CalcVBA dependency|adapter path dependency|members are missing|target identity|adapter Cargo target",
                ):
                    ledger_module._validate_loader_cargo_targets(root)

        for crate in (
            "calcforms-headless-runner",
            "calcforms-calcvba-adapter",
        ):
            with self.subTest(auto_build_script=crate), tempfile.TemporaryDirectory() as temporary:
                root = Path(temporary)
                make_repo(root)
                (root / "crates" / crate / "build.rs").write_text(
                    'fn main() { println!("cargo:rustc-cfg=decoy"); }\n',
                    encoding="utf-8",
                )
                with self.assertRaisesRegex(
                    ledger_module.LedgerError, "must not use a Cargo build script"
                ):
                    ledger_module._validate_loader_cargo_targets(root)

        alternate_feature_paths = {
            "package_features": '''
[features]
default = ["calcvba-com/fixture-typelibs"]
''',
            "target_dependency": '''
[target.'cfg(windows)'.dependencies]
calcvba-com = { git = "https://github.com/DnaCalc/CalcVBA.git", rev = "4cbe8b9c1ccc74c18dd76102b25b658cada4e625", features = ["fixture-typelibs"] }
''',
            "build_dependency": '''
[build-dependencies]
calcvba-com = { git = "https://github.com/DnaCalc/CalcVBA.git", rev = "4cbe8b9c1ccc74c18dd76102b25b658cada4e625" }
''',
            "aliased_dependency": '''
alternate-com = { package = "calcvba-com", git = "https://github.com/DnaCalc/CalcVBA.git", rev = "4cbe8b9c1ccc74c18dd76102b25b658cada4e625", features = ["fixture-typelibs"] }
''',
        }
        for label, addition in alternate_feature_paths.items():
            with self.subTest(label=label), tempfile.TemporaryDirectory() as temporary:
                root = Path(temporary)
                make_repo(root)
                path = root / "crates/calcforms-headless-runner/Cargo.toml"
                with path.open("a", encoding="utf-8") as stream:
                    stream.write(addition)
                with self.assertRaisesRegex(
                    ledger_module.LedgerError,
                    "default Cargo target identity|alternate CalcVBA dependency|CalcVBA dependency repository",
                ):
                    ledger_module._validate_loader_cargo_targets(root)

        for label, addition in alternate_feature_paths.items():
            with self.subTest(adapter_label=label), tempfile.TemporaryDirectory() as temporary:
                root = Path(temporary)
                make_repo(root)
                path = root / "crates/calcforms-calcvba-adapter/Cargo.toml"
                with path.open("a", encoding="utf-8") as stream:
                    stream.write(addition)
                with self.assertRaisesRegex(
                    ledger_module.LedgerError,
                    "production adapter Cargo target/dependency shape|production adapter CalcVBA dependency",
                ):
                    ledger_module._validate_loader_cargo_targets(root)

        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            make_repo(root)
            with (root / "Cargo.toml").open("a", encoding="utf-8") as stream:
                stream.write(
                    '\n[patch."https://github.com/DnaCalc/CalcVBA.git"]\n'
                    'calcvba-bind = { path = "../other" }\n'
                )
            with self.assertRaisesRegex(
                ledger_module.LedgerError, "patch/replace overrides"
            ):
                ledger_module._validate_loader_cargo_targets(root)

        for relative_config in (
            ".cargo/config.toml",
            "crates/calcforms-headless-runner/.cargo/config",
            "crates/calcforms-bootstrap/.CARGO/Config.toml",
        ):
            with self.subTest(
                relative_config=relative_config
            ), tempfile.TemporaryDirectory() as temporary:
                root = Path(temporary)
                make_repo(root)
                config_path = root / relative_config
                config_path.parent.mkdir(parents=True, exist_ok=True)
                config_path.write_text(
                    '''[patch."https://github.com/DnaCalc/CalcVBA.git"]
calcvba-bind = { path = "../other" }
''',
                    encoding="utf-8",
                )
                with self.assertRaisesRegex(
                    ledger_module.LedgerError, "repo-local Cargo config"
                ):
                    ledger_module._validate_loader_cargo_targets(root)

    def test_adapter_runtime_attach_handoff_has_reviewed_live_token_identity(self) -> None:
        ledger_module._validate_loader_adapter_runtime(REPO_ROOT)
        relative_path = "crates/calcforms-calcvba-adapter/src/runtime.rs"
        source = (REPO_ROOT / relative_path).read_text(encoding="utf-8")
        original = ".create_class_instance(form_class)"
        self.assertIn(original, source)
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            path = root / relative_path
            path.parent.mkdir(parents=True)
            path.write_text(
                source.replace(
                    original, '.create_class_instance("DisconnectedForm")', 1
                ),
                encoding="utf-8",
            )
            lib_path = root / "crates/calcforms-calcvba-adapter/src/lib.rs"
            lib_path.write_text(
                (
                    REPO_ROOT / "crates/calcforms-calcvba-adapter/src/lib.rs"
                ).read_text(encoding="utf-8"),
                encoding="utf-8",
            )
            with self.assertRaisesRegex(
                ledger_module.LedgerError, "full-source token identity"
            ):
                ledger_module._validate_loader_adapter_runtime(root)

    def test_manual_profile_respects_source_attribute_overrides_and_option_private(self) -> None:
        surface = {
            "modules": [
                {
                    "name": "Hidden",
                    "kind": "class_module",
                    "attributes": {"VB_Exposed": False},
                    "option_private_module": False,
                    "project_declared_exposed": False,
                    "project_declared_creatable": False,
                    "declarations": [],
                },
                {
                    "name": "Noncreatable",
                    "kind": "class_module",
                    "attributes": {"VB_Creatable": False},
                    "option_private_module": False,
                    "project_declared_exposed": False,
                    "project_declared_creatable": False,
                    "declarations": [],
                },
                {
                    "name": "Private",
                    "kind": "class_module",
                    "attributes": {},
                    "option_private_module": True,
                    "project_declared_exposed": False,
                    "project_declared_creatable": False,
                    "declarations": [],
                },
                {
                    "name": "ProceduralFalse",
                    "kind": "standard_module",
                    "attributes": {"VB_Exposed": False},
                    "option_private_module": False,
                    "project_declared_exposed": True,
                    "project_declared_creatable": False,
                    "declarations": [],
                },
            ]
        }
        policy = {
            "effective_loader_profiles": [
                {
                    "id": "manual",
                    "kind": "manual_calcvba_loader",
                    "source_path": "host.rs",
                    "modules": [
                        "Hidden",
                        "Noncreatable",
                        "Private",
                        "ProceduralFalse",
                    ],
                }
            ]
        }
        modules = ledger_module._index_source(surface, policy)["modules"]
        self.assertEqual([], modules["hidden"]["effective_loader_profiles"])
        self.assertEqual([], modules["private"]["effective_loader_profiles"])
        self.assertEqual(
            ["clean_basproj", "manual"],
            modules["proceduralfalse"]["effective_loader_profiles"],
        )
        self.assertEqual(
            ["manual"], modules["noncreatable"]["effective_loader_profiles"]
        )
        self.assertEqual(
            {"manual": False},
            modules["noncreatable"]["effective_creatable_by_profile"],
        )


class LedgerBaselineAndLocalInvariantTests(GeneratedLedgerTestCase):
    def test_generated_ledger_passes_both_validation_layers(self) -> None:
        self.assertEqual([], ledger_module.validate_ledger_structure(self.ledger))
        self.assertIsNotNone(
            self.strict_validate,
            "parity_ledger.validate_committed_ledger(repo_root, ledger) is required",
        )
        self.assertEqual([], self.strict_validate(REPO_ROOT, self.ledger))

    def test_authoritative_retention_census_includes_easy_to_drop_rows(self) -> None:
        rows = self.ledger["rows"]
        hidden_primary = [
            row
            for row in rows
            if row["row_kind"] == "type_contract"
            and row["contract"]["view"] == "primary"
            and row["visibility"]["hidden"]
            and row["source_authority"] == "fm20_typelib"
        ]
        version_two = [
            row
            for row in rows
            if row["row_kind"] == "type_contract"
            and row["exact_name"] in {
                "TextBox2",
                "CommandButton2",
                "Image2",
                "Label2",
                "ScrollBar2",
                "SpinButton2",
                "TabStrip2",
            }
        ]
        stdole = [
            row
            for row in rows
            if row["row_kind"] == "type_contract"
            and row["source_authority"] == "stdole_typelib"
        ]
        dual = [
            row
            for row in rows
            if row["row_kind"] == "type_contract"
            and row["contract"]["view"] == "dual_interface"
        ]
        spin = [
            row
            for row in rows
            if row["row_kind"] == "event_projection"
            and row["exact_name"] in {"SpinUp", "SpinDown"}
        ]

        self.assertGreater(len(hidden_primary), 0)
        self.assertEqual(7, len(version_two))
        self.assertEqual(12, len(stdole))
        self.assertEqual(37, len(dual))
        self.assertEqual(4, len(spin))
        self.assertEqual({"SpinUp": 2, "SpinDown": 2}, {
            name: sum(row["exact_name"] == name for row in spin)
            for name in ("SpinUp", "SpinDown")
        })
        self.assertEqual(2, len({row["facade_owner_type_id"] for row in spin}))

    def test_family_summaries_are_an_exact_row_partition(self) -> None:
        families = self.ledger["summary"]["owner_families"]
        self.assertEqual(
            self.ledger["summary"]["rows"],
            sum(family["rows"] for family in families.values()),
        )
        for family_name, family_summary in families.items():
            owner = family_summary["facade_owner_type_id"]
            family_rows = [
                row
                for row in self.ledger["rows"]
                if row.get("facade_owner_type_id") == owner
            ]
            self.assertEqual(
                {"facade_owner_type_id": owner, **ledger_module._row_counts(family_rows)},
                family_summary,
                family_name,
            )
        logical = self.ledger["summary"]["families"]
        self.assertEqual(
            self.ledger["summary"]["rows"],
            sum(family["rows"] for family in logical.values()),
        )
        type_names = {
            row["facade_owner_type_id"]: row["exact_name"]
            for row in self.ledger["rows"]
            if row["row_kind"] == "type_contract"
        }
        for family_name, family_summary in logical.items():
            family_rows = [
                row
                for row in self.ledger["rows"]
                if ledger_module._logical_family_key(row, type_names) == family_name
            ]
            self.assertEqual(
                {
                    "family_key": family_name,
                    "facade_owner_type_ids": sorted(
                        {
                            row["facade_owner_type_id"]
                            for row in family_rows
                            if isinstance(row.get("facade_owner_type_id"), str)
                        }
                    ),
                    **ledger_module._row_counts(family_rows),
                },
                family_summary,
            )
        self.assertTrue(
            {
                "overlay:UserForm",
                "family:Form",
                next(
                    type_id
                    for type_id, name in type_names.items()
                    if name == "UserForm" and type_id.endswith("|primary")
                ),
            }.issubset(set(logical["UserForm"]["facade_owner_type_ids"]))
        )

    def test_intrinsic_userforms_global_binding_is_not_laundered_by_type_identity(self) -> None:
        rows = [
            row
            for row in self.ledger["rows"]
            if row["row_kind"] == "overlay_global_binding"
        ]
        self.assertEqual(1, len(rows))
        row = rows[0]
        self.assertEqual("UserForms", row["exact_name"])
        self.assertEqual("public_standard_module_variable", row["contract"]["binding_kind"])
        self.assertIsNone(row["actual"]["matched"])
        self.assertEqual("missing", row["dimensions"]["bind"]["status"])

    def test_manual_loader_creatability_is_compared_per_effective_profile(self) -> None:
        by_name = {
            row["exact_name"]: row
            for row in self.ledger["rows"]
            if row["row_kind"] == "type_contract"
            and row["exact_name"] in {"CheckBox", "Image"}
            and row["contract"]["view"] == "primary"
        }
        self.assertEqual({"CheckBox", "Image"}, set(by_name))
        expected_profiles = ["headless_runner_forced", "bootstrap_forced"]
        expected_actual = {profile: True for profile in expected_profiles}

        check_box = by_name["CheckBox"]["actual"]
        self.assertFalse(check_box["source"]["project_declared_creatable"])
        self.assertEqual(
            expected_actual,
            check_box["identity_comparison"]["actual_creatable_by_profile"],
        )
        self.assertFalse(check_box["identity_comparison"]["expected_creatable"])
        self.assertEqual(
            expected_profiles,
            check_box["identity_comparison"]["creatability_mismatch_profiles"],
        )
        self.assertEqual("partial", by_name["CheckBox"]["dimensions"]["bind"]["status"])

        image = by_name["Image"]["actual"]
        self.assertFalse(image["source"]["project_declared_creatable"])
        self.assertEqual(
            expected_actual,
            image["identity_comparison"]["actual_creatable_by_profile"],
        )
        self.assertTrue(image["identity_comparison"]["expected_creatable"])
        self.assertEqual(
            [], image["identity_comparison"]["creatability_mismatch_profiles"]
        )
        self.assertFalse(
            any(
                "TYPEFLAG_FCANCREATE" in mismatch
                for mismatch in image["identity_comparison"]["mismatches"]
            )
        )

    def test_non_dispatch_abi_slot_drift_is_visible_and_rejected(self) -> None:
        mutated, row = _clone_with_row(
            self.ledger,
            lambda candidate: candidate["row_kind"] == "abi_adapter_member"
            and candidate["exact_name"] == "Name",
        )
        row["contract"]["accessors"]["get"]["vtable_offset"] = 32
        _rehash_signature(row["contract"]["accessors"]["get"])
        _normalize(mutated)
        self.assertStructureRejected(
            mutated, "ABI adapter accessor contract differs"
        )

    def test_event_signature_and_source_slot_cannot_drift_from_declaration(self) -> None:
        mutated, row = _clone_first_with_row(
            self.ledger,
            lambda candidate: candidate["row_kind"] == "event_projection",
        )
        signature = row["contract"]["event_signature"]
        signature["source_index"] += 1
        row["contract"]["source_function_index"] = signature["source_index"]
        _rehash_signature(signature)
        _normalize(mutated)
        self.assertStructureRejected(
            mutated,
            "projected event signature differs from declaration contract",
        )

    def test_non_dispatch_abi_member_slot_swap_is_rejected_coherently(self) -> None:
        mutated = dict(self.ledger)
        mutated["rows"] = list(self.ledger["rows"])
        font_type_id = next(
            row["declaration_owner_type_id"]
            for row in self.ledger["rows"]
            if row["row_kind"] == "type_contract" and row["exact_name"] == "IFont"
        )
        declaration_rows: dict[str, dict[str, Any]] = {}
        for member_name in ("Name", "Size"):
            index = _row_index(
                mutated["rows"],
                lambda row, name=member_name: row["row_kind"]
                == "declaration_member"
                and row["declaration_owner_type_id"] == font_type_id
                and row["exact_name"] == name,
            )
            declaration = copy.deepcopy(mutated["rows"][index])
            mutated["rows"][index] = declaration
            declaration_rows[member_name] = declaration
        name_signature = declaration_rows["Name"]["contract"]["accessors"]["get"]
        size_signature = declaration_rows["Size"]["contract"]["accessors"]["get"]
        for field in ("source_index", "vtable_offset"):
            name_signature[field], size_signature[field] = (
                size_signature[field],
                name_signature[field],
            )
        _rehash_signature(name_signature)
        _rehash_signature(size_signature)
        for declaration in declaration_rows.values():
            _sync_projection_contracts(mutated, declaration)
        _normalize(mutated)
        self.assertStructureRejected(
            mutated, "accessor/source-function index binding differs"
        )

    def test_non_dispatch_abi_coherent_impossible_offset_series_are_rejected(self) -> None:
        for label, offset_for_index in (
            ("negative_stride_20", lambda index: -240 + index * 20),
            ("positive_misaligned_stride_5", lambda index: 90 + index * 5),
        ):
            with self.subTest(label=label):
                mutated = dict(self.ledger)
                mutated["rows"] = list(self.ledger["rows"])
                font_type_id = next(
                    row["declaration_owner_type_id"]
                    for row in self.ledger["rows"]
                    if row["row_kind"] == "type_contract"
                    and row["exact_name"] == "IFont"
                )
                declaration_indices = [
                    index
                    for index, row in enumerate(mutated["rows"])
                    if row["row_kind"] == "declaration_member"
                    and row["declaration_owner_type_id"] == font_type_id
                ]
                for index in declaration_indices:
                    declaration = copy.deepcopy(mutated["rows"][index])
                    mutated["rows"][index] = declaration
                    for signature in declaration["contract"]["accessors"].values():
                        signature["vtable_offset"] = offset_for_index(
                            signature["source_index"]
                        )
                        _rehash_signature(signature)
                    _sync_projection_contracts(mutated, declaration)
                _normalize(mutated)
                self.assertStructureRejected(
                    mutated,
                    "ABI vtable offsets differ from authoritative alignment/layout",
                )

    def test_projection_modes_aliases_vardesc_and_overlay_subs_are_explicit(self) -> None:
        rows = self.ledger["rows"]
        self.assertEqual(
            {"ordinary": 1709, "direct": 85},
            {
                mode: sum(
                    row["row_kind"] == "surface_member"
                    and (("direct_facade" in row["contract"]) == (mode == "direct"))
                    for row in rows
                )
                for mode in ("ordinary", "direct")
            },
        )
        adapters = [row for row in rows if row["row_kind"] == "abi_adapter_member"]
        self.assertEqual(14, len(adapters))
        self.assertEqual({"IFont"}, {
            row["contract"]["abi_adapter"]["name"] for row in adapters
        })
        self.assertTrue(all(row["actual"] is None for row in adapters))
        font_type = next(
            row
            for row in rows
            if row["row_kind"] == "type_contract" and row["exact_name"] == "IFont"
        )
        self.assertEqual(
            {
                "alignment": 8,
                "size_instance": 8,
                "vtable_size": 200,
                "function_count": 22,
                "variable_count": 0,
                "implementation_count": 1,
            },
            font_type["contract"]["abi_layout"],
        )
        self.assertTrue(
            all(
                row["contract"]["type_contract_ref"] == font_type["row_id"]
                and row["contract"]["interface_layout"]
                == font_type["contract"]["abi_layout"]
                for row in adapters
            )
        )
        slots = sorted(
            (
                signature["source_index"],
                signature["vtable_offset"],
            )
            for row in adapters
            for signature in row["contract"]["accessors"].values()
        )
        self.assertEqual([(index, 24 + index * 8) for index in range(22)], slots)
        restricted = [
            row
            for row in rows
            if row["row_kind"] == "surface_member" and row["visibility"]["restricted"]
        ]
        self.assertEqual(441, len(restricted))
        self.assertTrue(
            all(
                row["actual"].get("comparison_skipped")
                == "authoritative FUNCFLAG_FRESTRICTED exclusion"
                and not row["actual"]["accessors"]
                for row in restricted
            )
        )
        self.assertEqual(
            "Currency",
            ledger_module._source_type_name(
                ledger_module._display_from_semantic_type(
                    {"kind": "scalar", "vt": 6, "vt_name": "VT_CY"}
                )
            ),
        )

        aliases = {
            row["exact_name"]: row
            for row in rows
            if row["row_kind"] == "type_contract"
            and row["source_authority"] == "fm20_typelib"
            and row["contract"]["typekind"] == "TKIND_ALIAS"
        }
        self.assertEqual(
            {"OLE_COLOR", "OLE_HANDLE", "OLE_OPTEXCLUSIVE", "PIROWSET"},
            set(aliases),
        )
        self.assertTrue(all(row["disposition"] == "alias_typedef" for row in aliases.values()))
        self.assertTrue(all(row["actual"]["source"] is None for row in aliases.values()))

        font_name = next(
            row
            for row in rows
            if row["row_kind"] == "surface_member"
            and "|106|primary" in row["facade_owner_type_id"]
            and row["exact_name"] == "Name"
        )
        picture_handle = next(
            row
            for row in rows
            if row["row_kind"] == "surface_member"
            and row["source_authority"] == "stdole_typelib"
            and row["exact_name"] == "Handle"
        )
        self.assertEqual({"get", "put"}, set(font_name["contract"]["accessors"]))
        self.assertEqual({"get"}, set(picture_handle["contract"]["accessors"]))
        self.assertEqual("missing", picture_handle["dimensions"]["default_binding"]["status"])

        render = next(
            row
            for row in rows
            if row["row_kind"] == "surface_member"
            and row["source_authority"] == "stdole_typelib"
            and row["exact_name"] == "Render"
        )
        self.assertEqual(
            "native_pointer_adapter_required",
            render["contract"]["projection_semantics"],
        )
        self.assertEqual("missing", render["dimensions"]["method"]["status"])

        overlay_subs = [
            row
            for row in rows
            if row["row_kind"] == "overlay_member"
            and row["contract"]["documentation"]["kind"] == "sub"
        ]
        self.assertEqual(5, len(overlay_subs))
        self.assertTrue(
            all(
                row["actual"]["accessors"]["func"]["expected_kind"] == "sub"
                for row in overlay_subs
            )
        )

    def test_persistence_leaf_censuses_and_nonclaims_are_explicit(self) -> None:
        rows = self.ledger["rows"]
        ms_categories = Counter(
            row["contract"]["category"]
            for row in rows
            if row["row_kind"] == "persistence_ms_oforms_fact"
        )
        frm_categories = Counter(
            row["contract"]["category"]
            for row in rows
            if row["row_kind"] == "persistence_frm_frx_fact"
        )
        self.assertEqual(ledger_module.EXPECTED_MS_PERSISTENCE_CATEGORIES, ms_categories)
        self.assertEqual(ledger_module.EXPECTED_FRM_PERSISTENCE_CATEGORIES, frm_categories)
        boundaries = [
            row
            for row in rows
            if row["row_kind"] == "persistence_frm_frx_fact"
            and row["contract"]["category"] == "boundaries"
        ]
        self.assertEqual(9, len(boundaries))
        self.assertTrue(all(row["row_status"] == "verified" for row in boundaries))
        self.assertTrue(
            all(row["row_status"] == "verified" for row in rows if row["row_kind"] == "persistence_aggregate")
        )

    def test_nonfinite_json_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary) / "nonfinite.json"
            path.write_text('{"value": NaN}', encoding="utf-8")
            with self.assertRaisesRegex(ledger_module.LedgerError, "non-finite JSON"):
                ledger_module.load_json_strict(path)

            lf = Path(temporary) / "lf.txt"
            crlf = Path(temporary) / "crlf.txt"
            lf.write_bytes(b"one\ntwo\n")
            crlf.write_bytes(b"one\r\ntwo\r\n")
            self.assertEqual(
                ledger_module._file_sha256(lf, "utf8_lf"),
                ledger_module._file_sha256(crlf, "utf8_lf"),
            )

    def test_every_input_schema_and_numeric_version_is_fail_closed(self) -> None:
        valid = {
            "fm20": {
                "schema": ledger_module.FM20_SCHEMA,
                "schema_version": 1,
            },
            "w005": {
                "schema": ledger_module.W005_SCHEMA,
                "schema_version": 1,
            },
            "ms_oforms": {"schema_version": ledger_module.MSOFORMS_SCHEMA},
            "frm_frx": {
                "schema": ledger_module.FRM_FRX_SCHEMA,
                "schema_version": 1,
            },
            "overlay": {
                "schema": ledger_module.OVERLAY_SCHEMA,
                "schema_version": 1,
            },
            "policy": {
                "schema": ledger_module.POLICY_SCHEMA,
                "schema_version": 1,
            },
        }
        mutations = {
            "w005_schema": ("w005", "schema", "wrong.schema.v1"),
            "ms_oforms_schema": (
                "ms_oforms",
                "schema_version",
                "wrong.schema.v1",
            ),
            "fm20_version": ("fm20", "schema_version", 2),
            "w005_bool_version": ("w005", "schema_version", True),
            "frm_frx_version": ("frm_frx", "schema_version", 0),
            "overlay_version": ("overlay", "schema_version", None),
            "policy_version": ("policy", "schema_version", "1"),
        }
        ledger_module._validate_input_schemas(valid)
        for label, (input_name, field, value) in mutations.items():
            mutated = copy.deepcopy(valid)
            mutated[input_name][field] = value
            with self.subTest(label=label), self.assertRaisesRegex(
                ledger_module.LedgerError, "wrong .* schema"
            ):
                ledger_module._validate_input_schemas(mutated)

    def test_internal_schema_versions_and_manifest_counts_are_type_strict(self) -> None:
        mutated = dict(self.ledger)
        mutated["schema_version"] = True
        self.assertStructureRejected(mutated, "schema_version must be 1")

        self.assertFalse(ledger_module._is_schema_version_one(True))
        self.assertTrue(ledger_module._is_schema_version_one(1))

        expected = ledger_module.build_expected_ledger_manifest(self.ledger)
        bool_count = copy.deepcopy(expected)
        self.assertEqual(1, bool_count["row_kinds"]["overlay_type"])
        bool_count["row_kinds"]["overlay_type"] = True
        self.assertFalse(
            ledger_module._type_strict_json_equal(expected, bool_count)
        )

    def test_invalid_status_empty_basis_and_empty_verified_evidence_are_rejected(self) -> None:
        cases: list[tuple[str, Callable[[dict[str, Any]], None], str]] = [
            (
                "status",
                lambda dimension: dimension.__setitem__("status", "looks_good"),
                "invalid status",
            ),
            (
                "basis",
                lambda dimension: dimension.__setitem__("basis", "  "),
                "empty basis",
            ),
            (
                "evidence",
                lambda dimension: (
                    dimension.__setitem__("status", "verified"),
                    dimension.__setitem__("evidence", []),
                ),
                "verified requires evidence",
            ),
        ]
        for label, mutate, expected in cases:
            with self.subTest(label=label):
                mutated, row = _clone_first_with_row(
                    self.ledger,
                    lambda candidate: candidate["dimensions"]["tests"]["status"]
                    == "missing",
                )
                mutate(row["dimensions"]["tests"])
                self.assertStructureRejected(mutated, expected)

    def test_every_row_requires_at_least_one_source_reference(self) -> None:
        mutated, row = _clone_with_row(
            self.ledger,
            lambda candidate: candidate["row_kind"] == "overlay_capability",
        )
        row["source_refs"] = []
        _normalize(mutated)
        self.assertStructureRejected(mutated, "source_refs must be nonempty strings")

    def test_vardesc_indices_reject_boolean_number_laundering(self) -> None:
        mutated, row = _clone_first_with_row(
            self.ledger,
            lambda candidate: candidate["row_kind"] == "declaration_variable"
            and candidate["contract"]["variable"]["index"] == 1,
        )
        row["contract"]["variable"]["index"] = True
        _normalize(mutated)
        self.assertStructureRejected(mutated, "VARDESC index is not integral")

    def test_loader_profile_creatability_source_and_comparison_cannot_drift(self) -> None:
        mutated, row = _clone_with_row(
            self.ledger,
            lambda candidate: candidate["row_kind"] == "type_contract"
            and candidate["exact_name"] == "CheckBox"
            and candidate["contract"]["view"] == "primary",
        )
        row["actual"]["source"]["effective_creatable_by_profile"][
            "headless_runner_forced"
        ] = False
        _normalize(mutated)
        self.assertStructureRejected(
            mutated, "loader-profile creatability crosslink differs"
        )

    def test_green_summary_summary_count_and_digest_tampering_are_rejected(self) -> None:
        green = dict(self.ledger)
        green["summary"] = copy.deepcopy(self.ledger["summary"])
        green["summary"]["green"] = True
        green["canonical_sha256"] = ledger_module.semantic_sha256(
            {
                "inputs": green["inputs"],
                "source_surface_sha256": green["source_surface_sha256"],
                "rows": green["rows"],
                "summary": green["summary"],
            }
        )
        self.assertStructureRejected(green, "summary is not exactly reconstructed")
        self.assertStructureRejected(green, "green summary cannot coexist")

        summary = dict(self.ledger)
        summary["summary"] = copy.deepcopy(self.ledger["summary"])
        summary["summary"]["rows"] += 1
        summary["canonical_sha256"] = ledger_module.semantic_sha256(
            {
                "inputs": summary["inputs"],
                "source_surface_sha256": summary["source_surface_sha256"],
                "rows": summary["rows"],
                "summary": summary["summary"],
            }
        )
        self.assertStructureRejected(summary, "summary is not exactly reconstructed")

        family_summary = dict(self.ledger)
        family_summary["summary"] = copy.deepcopy(self.ledger["summary"])
        first_family = next(iter(family_summary["summary"]["families"].values()))
        first_family["rows"] += 1
        family_summary["canonical_sha256"] = ledger_module.semantic_sha256(
            {
                "inputs": family_summary["inputs"],
                "source_surface_sha256": family_summary["source_surface_sha256"],
                "rows": family_summary["rows"],
                "summary": family_summary["summary"],
            }
        )
        self.assertStructureRejected(
            family_summary, "summary is not exactly reconstructed"
        )

        digest = dict(self.ledger)
        digest["canonical_sha256"] = "0" * 64
        self.assertStructureRejected(digest, "canonical_sha256 mismatch")


class SignatureAndIdentityAdversarialTests(unittest.TestCase):
    @staticmethod
    def _actual_parameter(**changes: Any) -> dict[str, Any]:
        parameter: dict[str, Any] = {
            "index": 0,
            "name": "Value",
            "type": "Boolean",
            "passing": "byval",
            "optional": False,
            "param_array": False,
            "array": False,
            "default": None,
        }
        parameter.update(changes)
        return parameter

    @staticmethod
    def _fm_signature(type_fact: dict[str, Any], optional_count: int = 0) -> dict[str, Any]:
        return {
            "optional_parameter_count": optional_count,
            "parameters": [
                {
                    "index": 0,
                    "name": "Value",
                    "name_state": "reported_by_GetNames",
                    "flags": {
                        "names": ["PARAMFLAG_FIN"],
                        "unknown_bits": 0,
                        "value": 1,
                    },
                    "default": {"state": "not_encoded"},
                    "type": type_fact,
                }
            ],
            "return": {
                "type": {"kind": "scalar", "vt": 24, "vt_name": "VT_VOID"}
            },
        }

    @staticmethod
    def _declaration(parameter: dict[str, Any]) -> dict[str, Any]:
        return {
            "kind": "sub",
            "parameters": [parameter],
            "return_type": None,
        }

    def test_fm20_comparator_rejects_passing_array_paramarray_and_default_drift(self) -> None:
        signature = self._fm_signature(
            {"kind": "scalar", "vt": 11, "vt_name": "VT_BOOL"}
        )
        compatible = ledger_module._signature_comparison(
            self._declaration(self._actual_parameter()), signature, "sub"
        )
        self.assertEqual("compatible_source_shape", compatible["status"])

        mutations = {
            "passing": {"passing": "byref"},
            "array": {"array": True},
            "param_array": {"array": True, "param_array": True, "passing": "byref"},
            "default": {"default": "True"},
            "name": {"name": "Wrong"},
        }
        for label, changes in mutations.items():
            with self.subTest(label=label):
                comparison = ledger_module._signature_comparison(
                    self._declaration(self._actual_parameter(**changes)),
                    signature,
                    "sub",
                )
                self.assertEqual("mismatch", comparison["status"])

    def test_array_and_paramarray_shapes_are_symmetric(self) -> None:
        array_type = {
            "kind": "safearray",
            "element": {"kind": "scalar", "vt": 11, "vt_name": "VT_BOOL"},
        }
        array_signature = self._fm_signature(array_type)
        actual_array = self._actual_parameter(array=True, passing="byref")
        self.assertEqual(
            "compatible_source_shape",
            ledger_module._signature_comparison(
                self._declaration(actual_array), array_signature, "sub"
            )["status"],
        )

        param_array_signature = self._fm_signature(array_type, optional_count=-1)
        actual_param_array = self._actual_parameter(
            array=True, param_array=True, passing="byref"
        )
        self.assertEqual(
            "compatible_source_shape",
            ledger_module._signature_comparison(
                self._declaration(actual_param_array), param_array_signature, "sub"
            )["status"],
        )
        scalar_signature = self._fm_signature(
            {"kind": "scalar", "vt": 11, "vt_name": "VT_BOOL"}
        )
        self.assertEqual(
            "mismatch",
            ledger_module._signature_comparison(
                self._declaration(actual_array), scalar_signature, "sub"
            )["status"],
        )

    def test_documented_overlay_signature_is_exact_about_parameter_shape(self) -> None:
        member = {
            "name": "Show",
            "parameters": [
                {
                    "name": "modal",
                    "type": "Variant",
                    "passing": "byref",
                    "passing_state": "documented",
                    "optional": True,
                    "default": "vbModal (1)",
                }
            ],
            "return_type": None,
        }
        signature = ledger_module._overlay_signature(member, "func")
        exact = {
            "kind": "sub",
            "parameters": [
                self._actual_parameter(
                    name="modal",
                    type="Variant",
                    passing="byref",
                    optional=True,
                    default="vbModal",
                )
            ],
            "return_type": None,
        }
        self.assertEqual(
            "compatible_source_shape",
            ledger_module._signature_comparison_overlay(exact, signature, "sub")[
                "status"
            ],
        )
        for label, changes in {
            "passing": {"passing": "byval"},
            "array": {"array": True},
            "param_array": {"array": True, "param_array": True},
            "default": {"default": "999"},
            "name": {"name": "wrong"},
        }.items():
            with self.subTest(label=label):
                mutated = copy.deepcopy(exact)
                mutated["parameters"][0].update(changes)
                self.assertEqual(
                    "mismatch",
                    ledger_module._signature_comparison_overlay(
                        mutated, signature, "sub"
                    )["status"],
                )

    def test_undocumented_overlay_setter_passing_cannot_be_called_compatible(self) -> None:
        # An indexed property Let: the index parameter's passing mode is observable to
        # callers, so an undocumented mode stays unresolved.  The final assigned-value
        # parameter is not observable (no caller can pass it by name or mode) and is
        # not compared.
        member = {
            "name": "Cell",
            "parameters": [
                {
                    "name": "Index",
                    "name_state": "documented",
                    "type": "Long",
                    "passing": "byref",
                    "passing_state": "undocumented_synthetic",
                    "optional": False,
                    "default": None,
                },
                {
                    "name": "Value",
                    "name_state": "undocumented_synthetic",
                    "type": "String",
                    "passing": "byref",
                    "passing_state": "undocumented_synthetic",
                    "optional": False,
                    "default": None,
                },
            ],
            "return_type": None,
        }
        signature = ledger_module._overlay_signature(member, "put")
        declaration = {
            "kind": "property_let",
            "parameters": [
                self._actual_parameter(name="Index", type="Long", passing="byref"),
                self._actual_parameter(index=1, type="String", passing="byref"),
            ],
            "return_type": None,
        }
        comparison = ledger_module._signature_comparison_overlay(
            declaration, signature, "property_let"
        )
        self.assertEqual("unresolved_source_lowering", comparison["status"])
        self.assertEqual(
            ["parameter 0 passing mode is not documented"],
            [item for item in comparison["unresolved"] if "passing" in item],
        )

    def test_assigned_value_parameter_of_a_setter_is_not_compared(self) -> None:
        member = {
            "name": "Caption",
            "parameters": [
                {
                    "name": "Value",
                    "name_state": "undocumented_synthetic",
                    "type": "String",
                    "passing": "byref",
                    "passing_state": "undocumented_synthetic",
                    "optional": False,
                    "default": None,
                }
            ],
            "return_type": None,
        }
        signature = ledger_module._overlay_signature(member, "put")
        declaration = {
            "kind": "property_let",
            "parameters": [self._actual_parameter(type="String", passing="byval")],
            "return_type": None,
        }
        comparison = ledger_module._signature_comparison_overlay(
            declaration, signature, "property_let"
        )
        self.assertEqual("compatible_source_shape", comparison["status"])

    def test_documentation_inferences_cannot_satisfy_overlay_item_signature(self) -> None:
        member = {
            "name": "Item",
            "parameters": [
                {
                    "name": "index",
                    "name_state": "not_documented",
                    "type": "Integer",
                    "type_state": "documentation_inference",
                    "optional": False,
                    "default": None,
                }
            ],
            "return_type": "UserForm",
            "return_type_state": "documentation_inference",
        }
        signature = ledger_module._overlay_signature(member, "func")
        declaration = {
            "kind": "function",
            "parameters": [
                self._actual_parameter(
                    name="index", type="Integer", passing="byref"
                )
            ],
            "return_type": "UserForm",
        }
        comparison = ledger_module._signature_comparison_overlay(
            declaration, signature, "function"
        )
        self.assertEqual("unresolved_source_lowering", comparison["status"])
        self.assertGreaterEqual(len(comparison["unresolved"]), 3)

    def test_string_defaults_preserve_case_and_internal_whitespace(self) -> None:
        exact, _ = ledger_module._compare_parameter_default(
            '"Foo  Bar"', {"state": "documented", "value": '"Foo  Bar"'}
        )
        wrong_case, _ = ledger_module._compare_parameter_default(
            '"foo  Bar"', {"state": "documented", "value": '"Foo  Bar"'}
        )
        wrong_space, _ = ledger_module._compare_parameter_default(
            '"Foo Bar"', {"state": "documented", "value": '"Foo  Bar"'}
        )
        encoded, _ = ledger_module._compare_parameter_default(
            '"Foo  Bar"',
            {"state": "encoded", "variant_type": "VT_BSTR", "value": "Foo  Bar"},
        )
        self.assertTrue(exact)
        self.assertTrue(encoded)
        self.assertFalse(wrong_case)
        self.assertFalse(wrong_space)

    def test_as_new_global_cannot_satisfy_intrinsic_userforms_binding(self) -> None:
        surface = {
            "modules": [
                {
                    "name": "Globals",
                    "kind": "standard_module",
                    "project_declared_exposed": True,
                    "declarations": [
                        {
                            "kind": "variable",
                            "name": "UserForms",
                            "type": "UserForms",
                            "as_new": True,
                        }
                    ],
                }
            ]
        }
        source_index = ledger_module._index_source(
            surface, {"effective_loader_profiles": []}
        )
        candidates, matched = ledger_module._global_binding_match(
            "UserForms", source_index
        )
        self.assertEqual(1, len(candidates))
        self.assertIsNone(matched)

    def test_array_global_cannot_satisfy_intrinsic_userforms_binding(self) -> None:
        surface = {
            "modules": [
                {
                    "name": "Globals",
                    "kind": "standard_module",
                    "project_declared_exposed": True,
                    "declarations": [
                        {
                            "kind": "variable",
                            "name": "UserForms",
                            "type": "UserForms",
                            "as_new": False,
                            "array": True,
                        }
                    ],
                }
            ]
        }
        source_index = ledger_module._index_source(
            surface, {"effective_loader_profiles": []}
        )
        candidates, matched = ledger_module._global_binding_match(
            "UserForms", source_index
        )
        self.assertEqual(1, len(candidates))
        self.assertIsNone(matched)

    @staticmethod
    def _identity_match(value: Any, attribute_name: str = "VB_UserMemId") -> dict[str, Any]:
        declaration = {
            "source_declaration_id": "source:000:0000",
            "member_attributes": (
                {} if value is None else {attribute_name: value}
            ),
        }
        return {"accessors": {"get": {"source_declaration": declaration}}}

    def test_member_identity_checks_every_explicit_case_insensitive_attribute(self) -> None:
        exact_default = ledger_module._default_binding_dimension(
            {"memid": 0, "default_member": True, "new_enum": False},
            self._identity_match(0, "vb_usermemid"),
        )
        self.assertEqual("implemented_unverified", exact_default["status"])
        quoted_numeric_default = ledger_module._default_binding_dimension(
            {"memid": 0, "default_member": True, "new_enum": False},
            self._identity_match("0"),
        )
        self.assertEqual("partial", quoted_numeric_default["status"])

        extra_default = ledger_module._default_binding_dimension(
            {"memid": 42, "default_member": False, "new_enum": False},
            self._identity_match(0),
        )
        self.assertEqual("partial", extra_default["status"])
        exact_ordinary = ledger_module._default_binding_dimension(
            {"memid": 42, "default_member": False, "new_enum": False},
            self._identity_match(42),
        )
        self.assertEqual("partial", exact_ordinary["status"])
        self.assertIn("recognizes only VB_UserMemId=0", exact_ordinary["basis"])
        exact_new_enum = ledger_module._default_binding_dimension(
            {"memid": -4, "default_member": False, "new_enum": True},
            self._identity_match(-4),
        )
        self.assertEqual("partial", exact_new_enum["status"])
        self.assertIn("_NewEnum=-4", exact_new_enum["basis"])
        absent_ordinary = ledger_module._default_binding_dimension(
            {"memid": 42, "default_member": False, "new_enum": False},
            self._identity_match(None),
        )
        self.assertEqual("not_applicable", absent_ordinary["status"])
        inline_default_match = self._identity_match(None)
        inline_default_match["accessors"]["get"]["source_declaration"][
            "default_member"
        ] = True
        inline_default = ledger_module._default_binding_dimension(
            {"memid": 42, "default_member": False, "new_enum": False},
            inline_default_match,
        )
        self.assertEqual("partial", inline_default["status"])

    def test_standard_module_cannot_satisfy_class_type_or_member_identity(self) -> None:
        type_fact = {
            "attributes": {
                "typekind_name": "TKIND_COCLASS",
                "type_flags": {
                    "names": ["TYPEFLAG_FCANCREATE"],
                    "unknown_bits": 0,
                    "value": 2,
                },
            }
        }
        wrong_kind = ledger_module._class_type_identity_comparison(
            type_fact,
            {
                "kind": "standard_module",
                "project_declared_creatable": False,
            },
        )
        self.assertTrue(wrong_kind["mismatches"])
        wrong_creatable = ledger_module._class_type_identity_comparison(
            type_fact,
            {
                "kind": "class_module",
                "effective_loader_profiles": ["clean_basproj"],
                "effective_creatable_by_profile": {"clean_basproj": False},
                "effective_loader_profile_evidence": {
                    "clean_basproj": "fixture#clean"
                },
            },
        )
        self.assertTrue(wrong_creatable["mismatches"])
        exact = ledger_module._class_type_identity_comparison(
            type_fact,
            {
                "kind": "class_module",
                "project_declared_creatable": False,
                "effective_loader_profiles": ["manual_forced"],
                "effective_creatable_by_profile": {"manual_forced": True},
                "effective_loader_profile_evidence": {
                    "manual_forced": "fixture#manual"
                },
            },
        )
        self.assertEqual([], exact["mismatches"])
        self.assertEqual(
            {"manual_forced": True}, exact["actual_creatable_by_profile"]
        )

        noncreatable_type = copy.deepcopy(type_fact)
        noncreatable_type["attributes"]["type_flags"] = {
            "names": [],
            "unknown_bits": 0,
            "value": 0,
        }
        forced_extra_identity = ledger_module._class_type_identity_comparison(
            noncreatable_type,
            {
                "kind": "class_module",
                "effective_loader_profiles": ["manual_forced"],
                "effective_creatable_by_profile": {"manual_forced": True},
                "effective_loader_profile_evidence": {
                    "manual_forced": "fixture#manual"
                },
            },
        )
        self.assertEqual(
            ["manual_forced"],
            forced_extra_identity["creatability_mismatch_profiles"],
        )

        signature = self._fm_signature(
            {"kind": "scalar", "vt": 11, "vt_name": "VT_BOOL"}
        )
        surface = {
            "modules": [
                {
                    "name": "CanonicalClass",
                    "kind": "standard_module",
                    "project_declared_exposed": True,
                    "declarations": [
                        {
                            **self._declaration(self._actual_parameter()),
                            "name": "SetValue",
                            "member_attributes": {},
                        }
                    ],
                }
            ]
        }
        policy = {
            "canonical_module_aliases": {},
            "effective_loader_profiles": [],
        }
        source_index = ledger_module._index_source(surface, policy)
        match = ledger_module._match_accessors(
            "CanonicalClass",
            "SetValue",
            {"func": signature},
            source_index,
            policy,
            set(),
        )
        self.assertEqual(
            "partial", ledger_module._accessor_dimension("func", match, False)["status"]
        )

    def test_unresolved_enum_expression_poisoning_stops_implicit_sequence(self) -> None:
        surface = {
            "modules": [
                {
                    "name": "Fixture",
                    "kind": "standard_module",
                    "project_declared_exposed": True,
                    "declarations": [
                        {
                            "kind": "enum",
                            "name": "Values",
                            "members": [
                                {"name": "A", "value": "SomeConst"},
                                {"name": "B", "value": None},
                                {"name": "C", "value": "10"},
                                {"name": "D", "value": None},
                            ],
                        }
                    ],
                }
            ]
        }
        policy = {"effective_loader_profiles": []}
        indexed = ledger_module._index_source(surface, policy)
        values = [
            indexed["nested_member_by_id"][key]["resolved_value"]
            for key in sorted(indexed["nested_member_by_id"])
        ]
        self.assertEqual([None, None, 10, 11], values)


class LedgerAuthoritativeMutationTests(GeneratedLedgerTestCase):
    def test_overlay_contract_mutation_is_rejected_after_coherent_rehash(self) -> None:
        mutated, row = _clone_with_row(
            self.ledger, lambda candidate: candidate["row_kind"] == "overlay_type"
        )
        row["contract"]["facts"][0] = "Invented replacement host fact."
        _normalize(mutated)
        self.assertStrictlyRejected(mutated)

    def test_equal_count_substitutions_cannot_erase_difficult_canonical_rows(self) -> None:
        cases: list[tuple[str, RowPredicate]] = [
            (
                "hidden-primary",
                lambda row: row["row_kind"] == "type_contract"
                and row["exact_name"] == "IDataAutoWrapper"
                and row["contract"]["view"] == "primary",
            ),
            (
                "version-two",
                lambda row: row["row_kind"] == "type_contract"
                and row["exact_name"] == "TextBox2",
            ),
            (
                "stdole",
                lambda row: row["row_kind"] == "type_contract"
                and row["exact_name"] == "GUID"
                and row["source_authority"] == "stdole_typelib",
            ),
            (
                "dual-companion",
                lambda row: row["row_kind"] == "type_contract"
                and row["exact_name"] == "IControl"
                and row["contract"]["view"] == "dual_interface",
            ),
            (
                "spin-event",
                lambda row: row["row_kind"] == "event_projection"
                and row["exact_name"] == "SpinUp"
                and "|112|primary" in row["facade_owner_type_id"],
            ),
        ]
        for label, predicate in cases:
            with self.subTest(label=label):
                mutated, row = _clone_with_row(self.ledger, predicate)
                row["visibility"]["hidden"] = not row["visibility"]["hidden"]
                _normalize(mutated)
                self.assertStrictlyRejected(mutated)

    def test_accessor_invoke_kind_change_is_rejected_after_signature_rehash(self) -> None:
        mutated, row = _clone_first_with_row(
            self.ledger,
            lambda candidate: candidate["row_kind"] == "declaration_member"
            and "get" in candidate["contract"]["accessors"]
            and "func" not in candidate["contract"]["accessors"],
        )
        signature = row["contract"]["accessors"].pop("get")
        self.assertEqual("INVOKE_PROPERTYGET", signature["invoke_kind"])
        signature["invoke_kind"] = "INVOKE_FUNC"
        _rehash_signature(signature)
        row["contract"]["accessors"]["func"] = signature
        row["contract"]["source_function_indices"] = [
            accessor["source_index"]
            for accessor in row["contract"]["accessors"].values()
        ]
        _sync_projection_contracts(mutated, row)
        _normalize(mutated)
        self.assertStrictlyRejected(mutated)

    def test_getnames_name_state_change_is_rejected_after_signature_rehash(self) -> None:
        def has_reported_name(candidate: dict[str, Any]) -> bool:
            return candidate["row_kind"] == "declaration_member" and any(
                parameter.get("name_state") == "reported_by_GetNames"
                for signature in candidate["contract"]["accessors"].values()
                for parameter in signature["parameters"]
            )

        mutated, row = _clone_first_with_row(self.ledger, has_reported_name)
        signature = next(
            signature
            for signature in row["contract"]["accessors"].values()
            if any(
                parameter.get("name_state") == "reported_by_GetNames"
                for parameter in signature["parameters"]
            )
        )
        parameter = next(
            parameter
            for parameter in signature["parameters"]
            if parameter.get("name_state") == "reported_by_GetNames"
        )
        parameter["name_state"] = "not_reported_by_GetNames"
        _rehash_signature(signature)
        _sync_projection_contracts(mutated, row)
        _normalize(mutated)
        self.assertStrictlyRejected(mutated)

    def test_userdefined_type_target_change_is_rejected_after_signature_rehash(self) -> None:
        def has_target(candidate: dict[str, Any]) -> bool:
            return candidate["row_kind"] == "declaration_member" and any(
                _first_semantic_target(parameter["type"]) is not None
                for signature in candidate["contract"]["accessors"].values()
                for parameter in signature["parameters"]
            )

        mutated, row = _clone_first_with_row(self.ledger, has_target)
        signature = next(
            signature
            for signature in row["contract"]["accessors"].values()
            if any(
                _first_semantic_target(parameter["type"]) is not None
                for parameter in signature["parameters"]
            )
        )
        target = next(
            target
            for target in (
                _first_semantic_target(parameter["type"])
                for parameter in signature["parameters"]
            )
            if target is not None
        )
        original_target = copy.deepcopy(target)
        replacement = next(
            copy.deepcopy(candidate_target)
            for candidate_row in self.ledger["rows"]
            if candidate_row["row_kind"] == "declaration_member"
            for candidate_signature in candidate_row["contract"]["accessors"].values()
            for candidate_parameter in candidate_signature["parameters"]
            for candidate_target in [_first_semantic_target(candidate_parameter["type"])]
            if candidate_target is not None and candidate_target != original_target
        )
        target.clear()
        target.update(replacement)
        _rehash_signature(signature)
        _sync_projection_contracts(mutated, row)
        _normalize(mutated)
        self.assertStrictlyRejected(mutated)

    def test_parameter_default_change_is_rejected_after_signature_rehash(self) -> None:
        def has_parameter(candidate: dict[str, Any]) -> bool:
            return candidate["row_kind"] == "declaration_member" and any(
                signature["parameters"]
                for signature in candidate["contract"]["accessors"].values()
            )

        mutated, row = _clone_first_with_row(self.ledger, has_parameter)
        signature = next(
            signature
            for signature in row["contract"]["accessors"].values()
            if signature["parameters"]
        )
        parameter = signature["parameters"][0]
        self.assertEqual("not_encoded", parameter["default"]["state"])
        parameter["default"] = {
            "state": "encoded",
            "variant_type": "VT_I4",
            "value": 8675309,
        }
        _rehash_signature(signature)
        _sync_projection_contracts(mutated, row)
        _normalize(mutated)
        self.assertStrictlyRejected(mutated)

    def test_coherent_status_basis_and_evidence_changes_are_rejected(self) -> None:
        cases: list[tuple[str, Callable[[dict[str, Any]], None]]] = [
            (
                "status",
                lambda dimension: (
                    dimension.__setitem__("status", "verified"),
                    dimension.__setitem__("evidence", ["invented:decisive-test"]),
                ),
            ),
            (
                "basis",
                lambda dimension: dimension.__setitem__(
                    "basis", "Plausible but noncanonical replacement rationale."
                ),
            ),
            (
                "evidence",
                lambda dimension: dimension["evidence"].append(
                    "invented:extra-evidence"
                ),
            ),
        ]
        for label, mutate in cases:
            with self.subTest(label=label):
                mutated, row = _clone_first_with_row(
                    self.ledger,
                    lambda candidate: candidate["row_kind"] == "surface_member"
                    and candidate["dimensions"]["tests"]["status"] == "missing",
                )
                mutate(row["dimensions"]["tests"])
                _normalize(mutated)
                self.assertStrictlyRejected(mutated)

    def test_runtime_api_claim_cannot_be_promoted_by_input_mutation(self) -> None:
        source_path = REPO_ROOT / ledger_module.DEFAULT_PATHS["frm_frx"]
        facts = ledger_module.load_json_strict(source_path)
        self.assertIs(facts["property_mappings"][0]["runtime_api_claim"], False)
        facts["property_mappings"][0]["runtime_api_claim"] = True
        with tempfile.TemporaryDirectory() as temporary:
            mutated_path = Path(temporary) / "frm_frx_mutated.json"
            mutated_path.write_text(
                json.dumps(facts, ensure_ascii=False), encoding="utf-8", newline="\n"
            )
            with self.assertRaisesRegex(
                ledger_module.LedgerError, "must retain runtime_api_claim=false"
            ):
                ledger_module.build_ledger(
                    REPO_ROOT, {"frm_frx": str(mutated_path)}
                )

    def test_binary_value_decoded_claim_cannot_be_promoted(self) -> None:
        source_path = REPO_ROOT / ledger_module.DEFAULT_PATHS["frm_frx"]
        facts = ledger_module.load_json_strict(source_path)
        self.assertIs(facts["property_mappings"][0]["binary_value_decoded"], False)
        facts["property_mappings"][0]["binary_value_decoded"] = True
        with tempfile.TemporaryDirectory() as temporary:
            mutated_path = Path(temporary) / "frm_frx_mutated.json"
            mutated_path.write_text(
                json.dumps(facts, ensure_ascii=False), encoding="utf-8", newline="\n"
            )
            with self.assertRaisesRegex(
                ledger_module.LedgerError, "must retain binary_value_decoded=false"
            ):
                ledger_module.build_ledger(
                    REPO_ROOT, {"frm_frx": str(mutated_path)}
                )

    def test_orphan_default_duplicate_mapping_and_w005_signature_drift_fail_closed(self) -> None:
        mutations: list[
            tuple[str, str, Callable[[dict[str, Any]], None], str]
        ] = [
            (
                "orphan-default",
                "ms_oforms",
                lambda facts: facts["default_matrix"][0].__setitem__(
                    "property", "DefinitelyMissingProperty"
                ),
                "orphan MS-OFORMS default",
            ),
            (
                "duplicate-mapping",
                "frm_frx",
                lambda facts: facts["property_mappings"].append(
                    copy.deepcopy(facts["property_mappings"][0])
                ),
                "duplicate FRM/FRX property mapping",
            ),
            (
                "w005-signature",
                "w005",
                lambda facts: facts["row_results"][0].__setitem__(
                    "current_signature_sha256", "0" * 64
                ),
                "W005 reconciliation signature drift",
            ),
        ]
        for label, input_name, mutate, expected in mutations:
            with self.subTest(label=label), tempfile.TemporaryDirectory() as temporary:
                facts = ledger_module.load_json_strict(
                    REPO_ROOT / ledger_module.DEFAULT_PATHS[input_name]
                )
                mutate(facts)
                mutated_path = Path(temporary) / f"{input_name}.json"
                mutated_path.write_text(
                    json.dumps(facts, ensure_ascii=False),
                    encoding="utf-8",
                    newline="\n",
                )
                with self.assertRaisesRegex(ledger_module.LedgerError, expected):
                    ledger_module.build_ledger(
                        REPO_ROOT, {input_name: str(mutated_path)}
                    )


if __name__ == "__main__":
    unittest.main()
