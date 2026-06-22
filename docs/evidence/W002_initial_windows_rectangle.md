# W002 Initial Windows Rectangle Evidence

Status: `CLOSED`
Initial evidence bead: `oxforms-dwm.6`
Structural repair bead: `oxforms-dwm.7`
Current closure bead: `oxforms-dwm.10`
Captured: 2026-06-22 on `C:\Work\DnaCalc\OxForms`

## Platform

- OS: Windows 10 Pro, version 2009, build 26200, 64-bit.
- Rust: `rustc 1.94.1 (e408947bf 2026-03-25)`.
- Cargo: `cargo 1.94.1 (29ea6fb6a 2026-03-24)`.
- Shell: PowerShell on Windows.

## Commits Reviewed

| Bead | Commit | Subject |
|---|---|---|
| `oxforms-dwm.2` | `6912a215af01637a2a861bd6cd1fc8b664e41bf1` | Scaffold PAL smoke workspace |
| `oxforms-dwm.3` | `28fce363dbc7a2c4c100ce4cfd3f3cf01ab0f032` | Implement headless FillRect renderer |
| `oxforms-dwm.4` | `d7085dc3b5dfe19c36688157c16ad8769391d1ee` | Execute OxVba rectangle smoke through PAL |
| `oxforms-dwm.5` | `b6f35cea8d490bce2b013d93bd2b198dd24f0e28` | Add Windows visible rectangle smoke |
| `oxforms-dwm.7` | see git commit for bead | Replace Debug.Print trace with host-injected PAL canvas |
| `oxforms-dwm.8` | see git commit for bead | Turn W002 smoke through OxForms VBA library project |
| `oxforms-dwm.9` | see git commit for bead | Rename OxVba-facing PAL adapter module |
| `oxforms-dwm.10` | see git commit for bead | Split OxVba adapter from PAL core |

## Structural Coupling Repairs

W002 was reopened after review found that the original OxVba smoke path captured
`Debug.Print` strings and decoded them in Rust. That proved VBA execution and
text parsing, but not useful coupling between VBA object dispatch and the
renderer. The `oxforms-dwm.7` repair uses OxVba's portable COM-like host
projection:

- Rust registers `OxForms.SmokeCanvas` in `PortableComProjection`.
- VBA executes `Set canvas = CreateObject("OxForms.SmokeCanvas")`.
- VBA calls `CreateSurface`, `FillRect`, and `Flush` on the projected object.
- The Rust PAL adapter records the `DisplayList`; `Flush` calls
  `oxforms_pal::render_headless` and returns the command count to VBA.

The old text trace decoder is no longer the W002 coupling proof.

W002 was reopened again for `oxforms-dwm.8` after review found the direct VBA
fixture still put too much PAL knowledge in the app side. The library-oriented
smoke now proves this direction:

```text
RectangleSmokeApp.basproj -> OxForms.basproj -> oxforms-oxvba-adapter -> oxforms-pal::render_headless
```

- OxVba loads `vba/smoke/projects/rectangle_app/RectangleSmokeApp.basproj`.
- The app project references `vba/oxforms/OxForms.basproj`.
- The app fixture creates a smoke-only OxForms form through `OxForms.NewSmokeForm`.
- The app fixture does not contain `OxForms.SmokeCanvas`.
- The OxForms library fixture owns the temporary PAL bridge and creates
  `OxForms.SmokeCanvas` internally.
- Rust records the same display list and `Flush` still calls
  `oxforms_pal::render_headless`.

W002 was reopened for `oxforms-dwm.10` after review found the adapter was still
compiled into `oxforms-pal`. The durable layering now is:

- `oxforms-pal`: host/runtime-independent PAL core, display-list types, and
  headless renderer.
- `oxforms-oxvba-adapter`: OxVba-specific `PortableDispatch`,
  `PortableComProjection`, and `Variant` marshalling.
- The smoke test lives with the adapter, not with the PAL core.

## Fixture And Artifacts

The W002 display-list fixture is `4x3`, has one `FillRect` command at
`x=1, y=1, width=2, height=1`, and uses RGBA bytes
`red=16, green=32, blue=48, alpha=255`.

Stable render diagnostic:

- `width=4`
- `height=3`
- `command_count=1`
- `framebuffer_hash=13797848596963948501`
- `hash_algorithm=fnv1a64-rgba8-framebuffer-v1`

Primary artifact paths and SHA-256 at capture time:

| Path | SHA-256 |
|---|---|
| `vba/smoke/fixtures/rectangle_fillrect_smoke.bas` | `4E9671219ED22E31EB7DB990DF663A952626E446CC8D4BA63681C6C578D17D1A` |
| `vba/smoke/projects/rectangle_app/RectangleSmokeApp.basproj` | `BD5775C79DE115FC2DA739DDBDA143BFBFB59EFBB4415CCEF7C3466EC4E926CD` |
| `vba/oxforms/OxForms.basproj` | `A1AEF98E5CCBCC2AC1F7E00D7CA9129E45860EBEFEFE3E33C5E9B3660C4D7AF7` |
| `vba/oxforms/OxForms.bas` | `52163EE34D952658D198C219B56C7446396F55715D953C800A6B835A8A5B417E` |
| `vba/oxforms/OxFormsSmokeForm.cls` | `CA61BCAF8AFCF530250F838B4781C127DC5C5476B083516E3FC6F4623362B9C3` |
| `Cargo.toml` | `8CA51BEE9FF76132B1FF15CF60B053D149DE61D8E01D9D696A3F0DB395DB224A` |
| `Cargo.lock` | `4E04B39846B4288942F176807CB7AE5E8FB3866325F9CDF402691D1EEB345974` |
| `crates/oxforms-pal/Cargo.toml` | `12655618D83E1CE890EECEAB081DF42BEA4E546CF2F1D774739E9C96B12A7AFA` |
| `crates/oxforms-pal/src/lib.rs` | `20BFC66648A4A7462F18EB87512659CFC5A4F7E7F2D73C3B277D34DA820D6C89` |
| `crates/oxforms-oxvba-adapter/Cargo.toml` | `99A9F3691B95CE5BD3C144BA9A5E1001BA018A2795253EFDBBA00831949C35D5` |
| `crates/oxforms-oxvba-adapter/src/lib.rs` | `991A9AEF01397BE6AFD22CD0D853E30785166FE1533AA9E8ECB5F0A179D08390` |
| `crates/oxforms-oxvba-adapter/tests/oxvba_rectangle_smoke.rs` | `2476AE6FC8B93E3829CCB91921934894A184F72537E8EE3CC3EEEC495F1A05AD` |
| `crates/oxforms-pal/examples/visible_rectangle_smoke.rs` | `2E765DC21A906A6CC5899775941FE420D1B7E7774F0B72F6594E4AC31431F07A` |

## Commands And Results

Rust format:

```powershell
cargo fmt --check
```

Result: exit code 0.

Rust lint:

```powershell
cargo clippy --workspace -- -D warnings
```

Result after repair: exit code 0.

Rust workspace tests:

```powershell
cargo test --workspace
```

Result after repair: exit code 0; five `oxforms-pal` unit tests passed, one
`oxforms-oxvba-adapter` integration test passed, and doc-tests had zero tests.

PAL core independence:

```powershell
cargo test -p oxforms-pal --no-default-features
```

Result after `oxforms-dwm.10`: exit code 0; five `oxforms-pal` unit tests
passed and doc-tests had zero tests. This proves the PAL core builds without
OxVba dependencies or adapter features.

Targeted headless rectangle fixture:

```powershell
cargo test -p oxforms-pal fill_rect_renders_expected_pixels_and_diagnostics -- --nocapture
```

Result: exit code 0; output included
`test tests::fill_rect_renders_expected_pixels_and_diagnostics ... ok`.
The checked hash is `13797848596963948501`.

Targeted OxVba smoke:

```powershell
cargo test -p oxforms-oxvba-adapter --test oxvba_rectangle_smoke -- --nocapture
```

Result: exit code 0; output included
`test oxvba_rectangle_smoke_app_loads_oxforms_library_and_reaches_renderer ... ok`.
This adapter-crate test loads
`vba/smoke/projects/rectangle_app/RectangleSmokeApp.basproj` through OxVba's
project-closure loader, follows its reference to `vba/oxforms/OxForms.basproj`,
registers only `OxForms.SmokeCanvas` in OxVba's portable COM-like projection,
and asserts that the app source does not directly create that PAL object. The
OxForms library creates the PAL canvas internally, calls `CreateSurface`,
`FillRect`, and `Flush`; `oxforms-oxvba-adapter` records the expected display
list, renders through the `oxforms-pal` core `render_headless`, and returns
command count `1` to VBA.

Windows visible smoke dry run:

```powershell
cargo run -p oxforms-pal --example visible_rectangle_smoke -- --dry-run
```

Result: exit code 0; output included:

```text
oxforms-pal W002 visible smoke: 4x3, commands=1, hash=13797848596963948501 (fnv1a64-rgba8-framebuffer-v1)
dry run: Windows visible window creation skipped
```

Windows visible smoke short native run:

```powershell
cargo run -p oxforms-pal --example visible_rectangle_smoke -- --hold-ms 300 --scale 32
```

Result: exit code 0; output included:

```text
oxforms-pal W002 visible smoke: 4x3, commands=1, hash=13797848596963948501 (fnv1a64-rgba8-framebuffer-v1)
visible smoke presented for up to 300 ms in a native Windows window
```

Dependency policy review:

```powershell
rg -n "\.\./OxVba|path\s*=|git\s*=|rev\s*=" Cargo.toml crates\oxforms-pal\Cargo.toml crates\oxforms-oxvba-adapter\Cargo.toml docs\SOURCE_REFERENCES.md
```

Result: exit code 0. Committed Cargo manifests use the pinned OxVba git rev
`501bf64d978afd14b820ebd03096f9fdcc247e38`; `../OxVba` appears only in
documentation describing local-only context and evidence boundaries.

Diff whitespace check:

```powershell
git diff --check
```

Result: exit code 0. Git reported only CRLF conversion warnings for changed
tracked text files.

Bead graph cycle check:

```powershell
br dep cycles
```

Result: exit code 0; output included `No dependency cycles detected.`

Ready-work review:

```powershell
br ready --json
```

Result during `oxforms-dwm.10`: `[]`. Reopening W002 and adding explicit
temporary dependencies blocked W003 execution while the PAL core/adapter split
repair was in progress. After W002 was reclosed, the command returned the
expected W003 starter beads `oxforms-fg9.1` and `oxforms-fg9.2`.

## Fresh-Eyes Review

Review scope: W002 docs, `docs/WORKSET_REGISTER.md`, `docs/SOURCE_REFERENCES.md`,
the PAL core crate API/tests/example, the OxVba adapter crate API/test, the
OxForms VBA library fixture, the app project fixture, VBA smoke fixture/readmes,
command names, dependency policy, smoke-only wording, and the bead graph.

Findings:

- The implemented surface remains W002-scoped: `DisplayCommand::FillRect`,
  versioned display list, RGBA8 color, deterministic headless renderer,
  OxVba-facing adapter dispatch, and Windows visible presentation of the same
  headless pixels.
- `oxforms-pal` has no OxVba dependencies; `PortableDispatch`,
  `PortableComProjection`, and `Variant` live in `oxforms-oxvba-adapter`.
- The repaired smoke proves the intended ownership direction: a VBA app project
  loads the OxForms VBA library, the app creates a smoke form through the
  library, the library creates `OxForms.SmokeCanvas`, member dispatch reaches
  Rust, and `Flush` drives the renderer.
- The code and docs continue to say smoke-only and do not claim `.frm`,
  `UserForm.Show`, intrinsic controls, input routing, text metrics, or MSForms
  parity.
- The Windows visible path was verified on this Windows host, so no blocker bead
  is needed for W002 closure.
- The committed dependency policy is pinned to OxVba commit
  `501bf64d978afd14b820ebd03096f9fdcc247e38`; no committed manifest uses a
  mutable `../OxVba` path.
- No new out-of-scope defect requiring a follow-up bead was found during this
  closure review.

Conclusion: W002 closure conditions are satisfied.
