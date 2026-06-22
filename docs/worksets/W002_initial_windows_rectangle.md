# W002 Initial Windows PAL Rectangle Smoke

Status: `CLOSED`
Epic bead: `oxforms-dwm`
Depends on: `W001_repo_bootstrap`
Owning plan bead: `oxforms-dwm.1`
Closed by: `oxforms-dwm.11`
Initial evidence bead: `oxforms-dwm.6`
Structural coupling repair: `oxforms-dwm.7`
Library-oriented smoke repair: `oxforms-dwm.8`
PAL adapter naming repair: `oxforms-dwm.9`
PAL core/adapter split repair: `oxforms-dwm.10`
Smoke module scoping review: `oxforms-dwm.11`

## Purpose

Build the first executable OxForms vertical slice: a VBA app project references
the OxForms VBA library, creates a smoke-only form-like object, the library
submits a minimal display-list command through an OxVba adapter, the adapter
maps it into the OxForms PAL core, and the renderer draws a small rectangle. The
slice should prove the project direction without pretending that full
`UserForm`, `.frm`, event routing, or MSForms parity exists yet.

This is the smallest useful vertical slice between the charter and implementation:

```
VBA app project -> OxForms VBA library -> OxVba adapter -> Rust PAL core -> rectangle evidence
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

The core PAL crate must not depend on OxVba or any other host runtime. OxVba's
`PortableDispatch`, `Variant`, and projection registration live in a sibling
adapter crate.

### 2. Headless Renderer

Implement a deterministic in-memory renderer first. It should accept the same
display list that the Windows smoke uses and produce a stable diagnostic/hash.

This keeps the first acceptance check available on every platform and avoids
making visible-window behavior the only proof of progress.

### 3. VBA Smoke Surface

Add a small VBA smoke app and a smoke-only OxForms VBA library fixture under the
OxForms repo. The app project references the library and asks it for a
form-like object. The library constructs the rectangle display list by calling an
OxForms PAL host object projected into OxVba.

The app-side shape is procedural and deliberately tiny, for example:

```vb
Public Sub Main()
    Dim form As Object

    Set form = OxForms.NewSmokeForm()
    renderedCommandCount = form.RenderRectangleSmoke()
End Sub
```

Inside the OxForms library, the smoke form may temporarily call
`CreateObject("OxForms.SmokeCanvas")`, then `CreateSurface`, `FillRect`, and
`Flush`. That API is a smoke API, not a compatibility surface. It exists to
prove that app-owned VBA can load OxForms, and OxForms-authored rendering
decisions can cross into Rust through the same host-injected, COM-like shape
planned for the real PAL.

### 4. OxVba Integration Boundary

Use the pinned OxVba baseline from `docs/SOURCE_REFERENCES.md` for committed
Rust dependencies. Local path overrides to `../OxVba` are acceptable only for
explicit coordinated development and must not become the shared default.

OxVba-specific adapter code lives in `oxforms-oxvba-adapter`. The adapter owns
the smoke `OxForms.SmokeCanvas` projection and maps dynamic OxVba calls onto
typed `oxforms-pal` display-list operations. `oxforms-pal` itself remains the
host/runtime-independent PAL core.

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

## Closure Evidence

W002 closed on 2026-06-22 after `oxforms-dwm.6` recorded reproducible evidence in
[`../evidence/W002_initial_windows_rectangle.md`](../evidence/W002_initial_windows_rectangle.md).
It was reopened and repaired by `oxforms-dwm.7` after review found that the
original `Debug.Print` trace proved only text emission, not meaningful
VBA-to-renderer coupling. It was then repaired by `oxforms-dwm.8` so the smoke
executes in the intended direction: app project -> OxForms VBA library -> Rust
PAL renderer. `oxforms-dwm.9` then removed the misleading Rust-hosting adapter
name, so the source layout matched that ownership direction. `oxforms-dwm.10`
split that adapter out of `oxforms-pal` into `oxforms-oxvba-adapter`, so the PAL
core no longer depends on OxVba crates. `oxforms-dwm.11` performed a final
fresh-eyes review and scoped the temporary projection as the adapter crate's
`smoke_canvas` module, leaving the adapter crate root as generic OxVba-facing
glue.

Final proved scope:

- The Rust PAL renders the W002 `FillRect` display list headlessly with stable
  diagnostic/hash `13797848596963948501`
  (`fnv1a64-rgba8-framebuffer-v1`).
- The OxVba-driven VBA smoke loads
  `vba/smoke/projects/rectangle_app/RectangleSmokeApp.basproj`, follows its
  project reference to `vba/oxforms/OxForms.basproj`, and executes the app
  module in that closure. The app creates an OxForms smoke form through the
  library and does not directly create `OxForms.SmokeCanvas`. The OxForms
  library creates the host-injected `OxForms.SmokeCanvas` through OxVba's
  portable COM-like projection owned by `oxforms-oxvba-adapter`, calls
  `CreateSurface`, `FillRect`, and `Flush`, and reaches the Rust PAL core. The
  adapter records the expected display list, `Flush` invokes the
  host-independent headless renderer, and the diagnostic/hash matches the Rust
  fixture.
- The `oxforms-pal` core builds and tests without OxVba dependencies.
- The W002 `OxForms.SmokeCanvas` projection is explicitly smoke-scoped in the
  `oxforms-oxvba-adapter::smoke_canvas` module; the adapter crate root no
  longer presents the smoke proof as the whole adapter API.
- The Windows visible example renders the same headless pixels in a short-lived
  native Windows window on the closure host.
- No W002 blocker or follow-up bead was required.

Residual work remains intentionally outside W002: `.frm` / `.frx` ingestion,
`UserForm.Show`, intrinsic controls, events, input routing, text metrics, image
decode, and MSForms parity. Those remain future workset scope.

## Bead Plan

| Bead | Purpose | Depends on | Acceptance |
|---|---|---|---|
| `oxforms-dwm.1` | Define this plan and acceptance evidence | `oxforms-dwm` | Workset docs, register, and bead graph agree. |
| `oxforms-dwm.2` | Scaffold Rust/VBA workspace | `oxforms-dwm.1` | Workspace is inspectable and uses pinned OxVba dependency policy. |
| `oxforms-dwm.3` | Implement display-list core and headless renderer | `oxforms-dwm.2` | Rust test renders a known rectangle and records stable diagnostics/hash. |
| `oxforms-dwm.4` | Execute VBA rectangle smoke through OxVba and PAL seam | `oxforms-dwm.3` | OxVba-driven smoke produces the same display-list/render diagnostic as the Rust fixture. |
| `oxforms-dwm.5` | Add Windows visible rectangle smoke backend | `oxforms-dwm.3` | Windows smoke paints the rectangle or non-Windows reports unsupported explicitly. |
| `oxforms-dwm.6` | Record evidence and fresh-eyes review | `oxforms-dwm.4`, `oxforms-dwm.5` | Evidence links commands, artifacts, hashes, and any platform blocker. |
| `oxforms-dwm.7` | Repair VBA smoke coupling through host-injected PAL canvas | `oxforms-dwm.4` | VBA creates `OxForms.SmokeCanvas`, calls drawing members, and Rust renders on `Flush`; the old text-trace proof is no longer the coupling mechanism. |
| `oxforms-dwm.8` | Turn W002 smoke through the OxForms VBA library project | `oxforms-dwm.7` | OxVba loads an app `.basproj` plus referenced `OxForms.basproj`; the app creates an OxForms smoke form, the library owns the PAL canvas, and Rust render evidence still matches the fixture. |
| `oxforms-dwm.9` | Rename OxVba PAL adapter module | `oxforms-dwm.8` | Rust module/file names say OxVba-facing PAL adapter rather than implying Rust hosts VBA; behavior and evidence stay unchanged. |
| `oxforms-dwm.10` | Split OxVba adapter from PAL core | `oxforms-dwm.9` | `oxforms-pal` has no OxVba dependencies; `oxforms-oxvba-adapter` owns the portable COM projection adapter and the OxVba smoke test. |
| `oxforms-dwm.11` | Fresh-eyes review W002 smoke architecture | `oxforms-dwm.10` | Smoke-only adapter API is scoped under `smoke_canvas`; `oxforms-pal` remains host-neutral; W002 evidence/register/checks reflect the final shape. |

## Closure Condition

W002 closes when all of these are true:

1. The Rust PAL can render a `FillRect` display list headlessly with a stable
   checked diagnostic/hash.
2. A VBA app project executed through OxVba references the OxForms VBA library,
   creates an OxForms smoke form-like object, and reaches the same rectangle
   display list through the library-owned host-injected PAL canvas object and
   the OxVba adapter crate;
   `Debug.Print` or stdout strings are not the coupling mechanism.
3. The `oxforms-pal` core has no OxVba dependency; OxVba-specific projection and
   `Variant` marshalling live outside the core.
4. A Windows visible smoke path exists and is either verified on Windows or records
   a concrete blocker with a follow-up bead.
5. Evidence records the commands, artifacts, platform, hashes, and fresh-eyes
   review outcome.
6. The spec/workset docs still state clearly that this is a smoke slice, not
   full Forms parity.

## Verification Shape

Expected checks once code exists:

| Surface | Check |
|---|---|
| Rust formatting | `cargo fmt --check` |
| Rust lint | `cargo clippy --workspace -- -D warnings` |
| Rust tests | `cargo test --workspace` |
| PAL core independence | `cargo test -p oxforms-pal --no-default-features` |
| Rectangle fixture | Targeted PAL/headless renderer test with stable diagnostic/hash |
| OxVba smoke | `cargo test -p oxforms-oxvba-adapter --test oxvba_rectangle_smoke -- --nocapture` |
| Windows smoke | Manual or ignored Windows-only command with explicit non-Windows diagnostic |
| Bead graph | `br dep cycles` and `br ready --json` |

## Risks And Controls

| Risk | Control |
|---|---|
| The smoke API accidentally becomes the compatibility API. | Name it as smoke-only and keep it out of the parity surface. |
| The smoke only proves text emission rather than renderer coupling. | Route VBA through OxVba's portable COM-like host projection and assert Rust-side display-list/render state. |
| OxVba adapter details leak into the PAL core. | Keep `oxforms-pal` free of OxVba dependencies; place `PortableDispatch`/`Variant` marshalling in `oxforms-oxvba-adapter`. |
| Visible window work becomes flaky or blocks CI. | Make headless rendering the automated oracle; keep Windows visible smoke manual/ignored if needed. |
| OxVba form-module support is not ready. | Use procedural/class VBA smoke first; track real form-module closure separately. |
| Cross-boundary command serialization churns too early. | Version the display list and keep W002 to `FillRect` only. |
| Local OxVba changes leak into committed manifests. | Use pinned git dependencies; local path overrides only in uncommitted/dev-specific config. |
