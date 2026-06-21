# W002 Initial Windows Rectangle Evidence

Status: `CLOSED`
Owning bead: `oxforms-dwm.6`
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
| `vba/smoke/fixtures/rectangle_fillrect_smoke.bas` | `0A52CAD8E3934FAF1A3A41FA100B8BE0F3BB7B952F63B5FE31A2A5AB6A5F0CF4` |
| `crates/oxforms-pal/src/lib.rs` | `EF2B7F5F3A5445B41C5E71999DAB491A5975A93580FEA26B9F525C543928C9D0` |
| `crates/oxforms-pal/tests/oxvba_rectangle_smoke.rs` | `E7915EC3412E8822BC6F20E878EE2286105839A14D8C7B0323078F9554A29F3B` |
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

Result: exit code 0; output included
`Finished dev profile [unoptimized + debuginfo] target(s) in 0.24s`.

Rust workspace tests:

```powershell
cargo test --workspace
```

Result: exit code 0; six `oxforms-pal` unit tests passed, one
`oxvba_rectangle_smoke` integration test passed, and doc-tests had zero tests.

Targeted headless rectangle fixture:

```powershell
cargo test -p oxforms-pal fill_rect_renders_expected_pixels_and_diagnostics -- --nocapture
```

Result: exit code 0; output included
`test tests::fill_rect_renders_expected_pixels_and_diagnostics ... ok`.
The checked hash is `13797848596963948501`.

Targeted OxVba smoke:

```powershell
cargo test -p oxforms-pal --test oxvba_rectangle_smoke -- --nocapture
```

Result: exit code 0; output included
`test oxvba_rectangle_smoke_reaches_pal_and_matches_rust_fixture ... ok`.
This executes `vba/smoke/fixtures/rectangle_fillrect_smoke.bas` through OxVba,
captures the smoke-only `Debug.Print` lines, decodes the same display list, and
asserts the same render diagnostic/hash.

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
rg -n "\.\./OxVba|path\s*=|git\s*=|rev\s*=" Cargo.toml crates\oxforms-pal\Cargo.toml docs\SOURCE_REFERENCES.md
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

Result before bead closure: `[]`. With `oxforms-dwm.6` in progress, no other
ready work was pending. The same command returned `[]` again after
`oxforms-dwm.6` and `oxforms-dwm` were closed.

## Fresh-Eyes Review

Review scope: W002 docs, `docs/WORKSET_REGISTER.md`, `docs/SOURCE_REFERENCES.md`,
the PAL crate API/tests/example, the VBA smoke fixture/readmes, command names,
dependency policy, smoke-only wording, and the bead graph.

Findings:

- The implemented surface remains W002-scoped: `DisplayCommand::FillRect`,
  versioned display list, RGBA8 color, deterministic headless renderer, OxVba
  smoke trace decode, and Windows visible presentation of the same headless pixels.
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
