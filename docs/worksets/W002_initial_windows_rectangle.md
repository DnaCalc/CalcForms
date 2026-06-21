# W002 Initial Windows PAL Rectangle Smoke

Status: `OPEN`
Epic bead: `oxforms-dwm`
Depends on: `W001_repo_bootstrap`
Owning plan bead: `oxforms-dwm.1`

## Purpose

Build the first executable OxForms vertical slice: VBA code emits a minimal
display-list command, Rust receives it through the PAL seam, and the renderer
draws a small rectangle. The slice should prove the project direction without
pretending that full `UserForm`, `.frm`, event routing, or MSForms parity exists
yet.

This is the smallest useful bridge between the charter and implementation:

```
VBA smoke code -> OxForms display list -> Rust PAL renderer -> rectangle evidence
```

Windows is the first platform target, but headless rendering is the primary
automated oracle so CI and non-interactive agents can verify the behavior.

## Non-goals

- No full `UserForm.Show` lifecycle.
- No `.frm` / `.frx` parser yet.
- No intrinsic control implementation.
- No text metrics, input routing, timers, clipboard, or image decode.
- No claim that the smoke API is the final public Forms API.
- No dependency on the mutable sibling `../OxVba` checkout in committed manifests.

## Architecture Slice

### 1. Rust PAL Core

Create the first `oxforms-pal` crate with deliberately small data types:

- `Rect` using logical pixels for the smoke slice.
- `Color` with explicit byte order.
- `DisplayCommand::FillRect`.
- `DisplayList` with a version field.
- `RenderDiagnostics` with at least dimensions, command count, and deterministic
  hash or checksum.

The command vocabulary should be boring on purpose. A single `FillRect` is enough
to settle serialization, validation, and rendering evidence without introducing
theme or control semantics too early.

### 2. Headless Renderer

Implement a deterministic in-memory renderer first. It should accept the same
display list that the Windows smoke uses and produce a stable diagnostic/hash.

This keeps the first acceptance check available on every platform and avoids
making visible-window behavior the only proof of progress.

### 3. VBA Smoke Surface

Add a small VBA smoke source under the OxForms repo that constructs the rectangle
display list and submits it through the OxForms PAL host seam under OxVba.

The initial VBA shape can be procedural or class-based, for example:

```vb
Public Sub Main()
    Dim canvas As OxFormsSmokeCanvas
    Set canvas = OxForms.CreateSmokeCanvas(160, 96)

    canvas.FillRect 20, 18, 80, 36, &H003399FF
    canvas.Flush
End Sub
```

That API is a smoke API, not a compatibility surface. It exists to prove that
VBA-authored rendering decisions can cross into the PAL as a batch.

### 4. OxVba Integration Boundary

Use the pinned OxVba baseline from `docs/SOURCE_REFERENCES.md` for committed
Rust dependencies. Local path overrides to `../OxVba` are acceptable only for
explicit coordinated development and must not become the shared default.

Known boundary at W002 start:

- OxVba has `oxvba-symbol::ModuleKind::Form`.
- OxVba still marks form-module lifecycle and `UserForm` integration as planned
  in `MODPROJ-030`.
- Therefore W002 should use a procedural/class smoke harness rather than blocking
  on full `.frm` materialization.

### 5. Windows Visible Smoke

Add the smallest Windows-backed visible path that can paint the same display list
into a window. The visible smoke may be manual or ignored by default; it should
not be the only automated acceptance check.

The Windows path should:

- use the same `DisplayList` as the headless test;
- open a small window or surface;
- paint the rectangle;
- close deterministically or document the manual close step;
- report a clear unsupported diagnostic on non-Windows hosts.

Current smoke command:

```powershell
cargo run -p oxforms-pal --example visible_rectangle_smoke
```

On Windows this presents the W002 `FillRect` fixture in a short-lived native window
and closes automatically. Use `-- --dry-run` to exercise the command without opening
a window. On non-Windows hosts the command prints an explicit unsupported diagnostic;
the headless renderer remains the automated oracle.

## Bead Plan

| Bead | Purpose | Depends on | Acceptance |
|---|---|---|---|
| `oxforms-dwm.1` | Define this plan and acceptance evidence | `oxforms-dwm` | Workset docs, register, and bead graph agree. |
| `oxforms-dwm.2` | Scaffold Rust/VBA workspace | `oxforms-dwm.1` | Workspace is inspectable and uses pinned OxVba dependency policy. |
| `oxforms-dwm.3` | Implement display-list core and headless renderer | `oxforms-dwm.2` | Rust test renders a known rectangle and records stable diagnostics/hash. |
| `oxforms-dwm.4` | Execute VBA rectangle smoke through OxVba and PAL seam | `oxforms-dwm.3` | OxVba-driven smoke produces the same display-list/render diagnostic as the Rust fixture. |
| `oxforms-dwm.5` | Add Windows visible rectangle smoke backend | `oxforms-dwm.3` | Windows smoke paints the rectangle or non-Windows reports unsupported explicitly. |
| `oxforms-dwm.6` | Record evidence and fresh-eyes review | `oxforms-dwm.4`, `oxforms-dwm.5` | Evidence links commands, artifacts, hashes, and any platform blocker. |

## Closure Condition

W002 closes when all of these are true:

1. The Rust PAL can render a `FillRect` display list headlessly with a stable
   checked diagnostic/hash.
2. A VBA smoke source executed through OxVba emits or submits the same rectangle
   display list and reaches the PAL seam.
3. A Windows visible smoke path exists and is either verified on Windows or records
   a concrete blocker with a follow-up bead.
4. Evidence records the commands, artifacts, platform, hashes, and fresh-eyes
   review outcome.
5. The spec/workset docs still state clearly that this is a smoke slice, not
   full Forms parity.

## Verification Shape

Expected checks once code exists:

| Surface | Check |
|---|---|
| Rust formatting | `cargo fmt --check` |
| Rust lint | `cargo clippy --workspace -- -D warnings` |
| Rust tests | `cargo test --workspace` |
| Rectangle fixture | Targeted PAL/headless renderer test with stable diagnostic/hash |
| OxVba smoke | Targeted command that executes the VBA rectangle smoke through the pinned OxVba baseline |
| Windows smoke | Manual or ignored Windows-only command with explicit non-Windows diagnostic |
| Bead graph | `br dep cycles` and `br ready --json` |

## Risks And Controls

| Risk | Control |
|---|---|
| The smoke API accidentally becomes the compatibility API. | Name it as smoke-only and keep it out of the parity surface. |
| Visible window work becomes flaky or blocks CI. | Make headless rendering the automated oracle; keep Windows visible smoke manual/ignored if needed. |
| OxVba form-module support is not ready. | Use procedural/class VBA smoke first; track real form-module closure separately. |
| Cross-boundary command serialization churns too early. | Version the display list and keep W002 to `FillRect` only. |
| Local OxVba changes leak into committed manifests. | Use pinned git dependencies; local path overrides only in uncommitted/dev-specific config. |
