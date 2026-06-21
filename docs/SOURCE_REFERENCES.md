# OxForms Source References

Status: bootstrap reference map
Last updated: 2026-06-21
Owning bead: `oxforms-rzk.1`

This file names external source-of-truth inputs that OxForms reads but does not
own. Update it whenever a Foundation source mirror or OxVba development baseline
changes.

## Foundation Forms Specification

The primary clean-room forms specification is **[MS-OFORMS] Office Forms Binary
File Formats**. Read it through the sibling Foundation repository rather than by
adding ad hoc downloads to OxForms.

Foundation reference surfaces:

- Doctrine: `../Foundation/REFERENCE_SPEC_FORMAT_AND_CONFORMANCE.md`
- Seeds: `../Foundation/reference/spec_seeds.csv`
- Mirror index: `../Foundation/reference/index.csv`
- Raw mirror root: `../Foundation/reference/downloads/...`

Observed Foundation state on 2026-06-21:

- HEAD: `cbf24b746e66860242fd7b0d87ffac5d0e71807d`
- Worktree caveat: `reference/index.csv` and `reference/spec_seeds.csv` were
  modified, and the MS-OFORMS mirror directory was still untracked. Treat the
  paths and hashes below as the local bootstrap pointer until Foundation lands
  the mirror in git.

Pinned MS-OFORMS artifacts:

| Artifact | Path from OxForms | Revision | SHA-256 |
|---|---|---|---|
| Authoritative DOCX | `../Foundation/reference/downloads/officeprotocoldocs-f5hpbjgea6b8gneq.b02.azurefd.net/files/MS-OFORMS/[MS-OFORMS]-250819.docx` | 9.1, 2025-08-19 | `7bbbbdc43407524fe2af99c070dfc358cc67404e5224b56d5cdabbc4736c9158` |
| Authoritative PDF | `../Foundation/reference/downloads/officeprotocoldocs-f5hpbjgea6b8gneq.b02.azurefd.net/files/MS-OFORMS/[MS-OFORMS].pdf` | 9.1, 2025-08-19 | `37e72c8605244ebd28c2f247f9605d858fb44c194f835867d8b9ecedcb744db4` |

Online seed:

- `https://learn.microsoft.com/en-us/openspecs/office_file_formats/ms-oforms/9c79701a-8c3e-4429-a139-b60ac3a1d50a`

OxForms uses MS-OFORMS for serialized form/control property facts, enums,
defaults, appearance vocabulary, and persistence matrices. The in-document
binary codec remains OxDoc scope; OxForms meets OxDoc at `.frm` / `.frx`.

Adjacent Foundation source for that boundary:

- **[MS-OVBA] Office VBA File Format Structure**
  - `../Foundation/reference/downloads/learn.microsoft.com/en-us/openspecs/office_file_formats/ms-ovba/b39ac32f-0ce1-4533-9297-2ff3ff62c9ec.md`
  - Index hash: `de6157f4b4a5e2c0806837176cb8cfd32ffadb86ac08b06276bd5e3c31d656e4`

## OxVba Development Baseline

OxForms depends on OxVba, but the sibling `../OxVba` checkout is under active
development and had local uncommitted edits when this map was written. Do not use
a floating sibling path as a shared stable input.

Current OxForms bootstrap baseline:

- Repo: `https://github.com/DnaCalc/OxVba.git`
- Commit: `501bf64d978afd14b820ebd03096f9fdcc247e38`
- Branch relation observed: `master` == `origin/master`
- Commit subject: `Harden COM runtime object transport`
- Observed on: 2026-06-21

Why this baseline rather than a release tag:

- The latest tag, `v0.1.2`, is 2081 commits behind this commit.
- The workspace package version still reports `0.1.2`, so the semver value alone
  is not a useful dependency baseline.
- The current commit includes much newer project/reference, COM, event,
  default-member, native-body, and host-object work that forms integration will
  rely on.

When Rust code lands in OxForms, prefer pinned git dependencies:

```toml
[dependencies]
oxvba-project = { git = "https://github.com/DnaCalc/OxVba.git", rev = "501bf64d978afd14b820ebd03096f9fdcc247e38" }
oxvba-host = { git = "https://github.com/DnaCalc/OxVba.git", rev = "501bf64d978afd14b820ebd03096f9fdcc247e38" }
oxvba-symbol = { git = "https://github.com/DnaCalc/OxVba.git", rev = "501bf64d978afd14b820ebd03096f9fdcc247e38" }
oxvba-bind = { git = "https://github.com/DnaCalc/OxVba.git", rev = "501bf64d978afd14b820ebd03096f9fdcc247e38" }
oxvba-bundle = { git = "https://github.com/DnaCalc/OxVba.git", rev = "501bf64d978afd14b820ebd03096f9fdcc247e38" }
oxvba-runtime = { git = "https://github.com/DnaCalc/OxVba.git", rev = "501bf64d978afd14b820ebd03096f9fdcc247e38" }
```

Use local `../OxVba` path overrides only for explicitly coordinated cross-repo
development and keep them out of committed shared manifests unless that bead is
about the coordinated dependency change.

Known forms integration boundary in this baseline:

- `../OxVba/docs/evidence/language/MS_VBAL_MODULE_PROJECT_REQUIREMENTS.csv` row
  `MODPROJ-030` still marks form-module lifecycle and UserForm integration as
  `planned` / `forms-deferred`.
- `oxvba-symbol` has `ModuleKind::Form`, but `oxvba-project` `.basproj` parsing
  currently exposes `<Module>`, `<ClassModule>`, and `<DocumentModule>` only.
- OxForms should track form-module materialization, default-instance exposure,
  designer-declared control members, and event handler wiring as OxVba
  integration closure work rather than papering over the gap locally.

## Baseline Update Procedure

When changing either baseline:

1. Record the old and new commit or artifact hash in this file.
2. Note the sibling repo worktree status used for the decision.
3. Update the relevant spec/workset/evidence surfaces in the same bead.
4. Run the checks available for the touched surfaces.
5. Add or update handovers when the source-of-truth repo must act.
