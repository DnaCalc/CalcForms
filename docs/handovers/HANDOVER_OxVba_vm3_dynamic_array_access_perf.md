# HANDOVER → OxVba: vm3 dynamic-array element access is O(N) (array loops are O(N²))

Status: `RESOLVED by 30099710 (round 2 — O(1) class-field element access; array loops O(N))` · From: OxForms · To: OxVba · Date: 2026-06-29 (resolved 2026-06-30)
OxVba revs: original report exercised `2b817614` (pre-array-fix baseline); round 1 = `019a39df`; **RESOLVED against `30099710` (round 2)** — pinned by OxForms via git rev.
Policy: per OxForms memory `oxvba-vm3-handover-policy`, perf pathologies vm3 exhibits under the
OxForms workload are handed to OxVba to **fix**, not worked around in OxForms — OxForms is the
workload that hardens OxVba. This is such a report.

## Summary

> **Historical (original report, pre-fix `2b817614`).** This Summary and the Diagnosis / Isolation
> sections below describe the now-fixed state; see **RESOLVED — round 2** below for the current state.

On the vm3 interpreter (`enable_jit=false`), **reading an element of a module-level dynamic array
inside a loop (`arr(i)`) scales O(N) in the array length N**, so a simple loop that indexes arrays is
**O(N²)**. A 100-element hit-test loop takes **130 ms**; a 400-element one takes **2.2 s**. The
equivalent native Rust loop is ~1 µs. This is a *general* pathology (it cripples any non-trivial VBA
loop over arrays), not specific to the hit-test code that surfaced it.

## Update — post-fix re-measurement (OxVba 019a39df, 2026-06-30)

Commit 019a39df ("vm3-perf: O(1) dynamic-array element access; array loops O(N) not O(N^2)")
**improved the per-access constant ~5-6x but did NOT change the complexity** — the OxForms probe still
measures element access as **O(N)**. Clean min-of-9-trials isolation (`array_access_isolation_on_vm3`,
Reps=2000), one array read per iteration:

| N | ScanPlain (no array — flat) | per array read |
|---|---|---|
| 50 | 17.2 ms | 25.6 µs |
| 100 | 17.4 ms | 42.4 µs |
| 200 | 18.5 ms | 113.5 µs |
| 400 | 19.6 ms | 173.0 µs |
| 800 | 17.1 ms | 322.2 µs |

`ScanPlain` (no array) is flat across N; `per-read` grows ~12.6x over a 16x N range (50→800) → still
~O(N) per access, so array loops remain O(N²). At N=400 per-read fell from ~1107 µs (pre-fix
2b817614) to ~173 µs — a real ~6x win — but a forms hot path over many controls still degrades
quadratically. Both `arr(i)` (direct loop var, the scaling probe) and `arr(i Mod n)` (this isolation)
show it, and the flat `ScanPlain` baseline rules out measurement noise. **Status: OPEN — partially
addressed.** Possible angle for OxVba: the fix may not cover module-level `Private` dynamic `Long`
array element access, or a residual O(N) indexing factor remains in this path.

## RESOLVED — round 2 (OxVba 30099710, 2026-06-30)

Round 1 (`019a39df`) fixed *general* dynamic-array element access but, as the OxForms probe caught,
left **class-field** dynamic arrays (`Private mX()` inside a class — exactly what this bench uses)
still O(N). OxVba reopened the defect (OxVba bead `bd-us4v`, commit `20225701` "class-field array
access still O(N)") and shipped **round 2 (commit `30099710`, "O(1) class-field array access")**. The same clean min-of-9-trials isolation
(`array_access_isolation_on_vm3`, Reps=2000) now measures element access as **O(1)**:

| N | ScanPlain (no array) | per array read — round 2 (`30099710`) | per array read — round 1 (`019a39df`) |
|---|---|---|---|
| 50 | 17.7 ms | 3.75 µs | 25.6 µs |
| 100 | 17.9 ms | 4.04 µs | 42.4 µs |
| 200 | 18.1 ms | 3.88 µs | 113.5 µs |
| 400 | 17.4 ms | 3.95 µs | 173.0 µs |
| 800 | 18.1 ms | 3.94 µs | 322.2 µs |

per-read is **flat ~3.9 µs across a 16× N sweep** (round 1 fanned out ~12.6×) → **O(1) element
access**. Correspondingly the `HitTestAll` loop is now **O(N)** (per-element flat ~33 µs vs the pre-fix
(`2b817614`) 0.39 ms→5.57 ms per-element ramp = O(N²); see the "Measurements" table below — round 1
was not separately benchmarked for `HitTestAll`). The complexity ask below ("make element access O(1)
so array loops are O(N)") is **fully satisfied**; the constant also dropped ~6–82× vs pre-fix.

Residual (not a defect — interpreter property): the per-op interpreter constant remains (~8.5 µs/iter
base + ~3.9 µs/read), so a pure-interpreter full scan over many controls is still ~33 µs/control. That
is a separate matter from the array pathology and is addressed OxForms-side by a spatial index (or the
JIT), not by OxVba. The VBA-vs-Rust hit-test home is therefore no longer blocked by this defect; the
firm choice still needs an indexed-pick + per-frame measurement OxForms-side (bead `oxforms-bqr`,
which stays open for that).

## Reproduction

Repo: OxForms. Files:
- `vba/smoke/fixtures/lex_hittest_bench_form.cls` — a class holding N control rects in four
  `Private` dynamic `Long` arrays (`mX/mY/mW/mH`), with `HitTestAll(X, Y)` looping `0..mN-1` and
  reading those arrays, and a `Noop()` for crossing-overhead isolation.
- `crates/oxforms-oxvba-adapter/tests/oxvba_lex_hittest_bench.rs` — drives a vm3 image session
  (`enable_jit=false`), calls `Setup(N)` then times N-scaled runs of `HitTestAll` vs `Noop` vs a
  native-Rust equivalent.

Run: `cargo test -p oxforms-oxvba-adapter --test oxvba_lex_hittest_bench -- --ignored --nocapture`

The hot loop (VBA):

```vba
For i = 0 To mN - 1
    If (X >= mX(i)) And (X < mX(i) + mW(i)) And _
       (Y >= mY(i)) And (Y < mY(i) + mH(i)) Then
        hit = i
    End If
Next i
```

## Measurements (per call, vm3 interpreter)

| N | native Rust | VBA `HitTestAll` | bare crossing (`Noop`) | VBA compute (`HitTestAll − Noop`) | per-element |
|---|---|---|---|---|---|
| 25 | 315 ns | 9.7 ms | 5.6 µs | 9.7 ms | 0.39 ms |
| 50 | 560 ns | 35.0 ms | 5.7 µs | 35.0 ms | 0.70 ms |
| 100 | 1.1 µs | 130.4 ms | 7.8 µs | 130.4 ms | 1.30 ms |
| 200 | 1.8 µs | 569.5 ms | 8.7 µs | 569.5 ms | 2.85 ms |
| 400 | 6.1 µs | 2226 ms | 6.7 µs | 2226 ms | 5.57 ms |

## Diagnosis

- **The boundary crossing is NOT the cause.** `Noop` (one `invoke_member_values` into an empty VBA
  function) is ~5–9 µs and flat across N. The cost is entirely inside the VBA loop.
- **The loop is O(N²).** Doubling N ~quadruples total time, and the **per-element** cost itself
  doubles with N (0.39 → 0.70 → 1.30 → 2.85 → 5.57 ms). A linear loop would have constant per-element
  cost.
- **By elimination, `arr(i)` is O(N).** Every operation in the loop body is an O(1) `Long`
  comparison / `And` / add, **except** the dynamic-array element reads (`mX(i)`, `mW(i)`, `mY(i)`,
  `mH(i)`). The only operation whose cost can grow with N is the array element access — so element
  access is O(N), not O(1). **Confirmed directly by isolation — see below.**

## Isolation — the array read is the O(N) op (confirmed)

`array_access_isolation_on_vm3` (same test file) runs two identical fixed-length loops
(`Reps = 1000`) that differ ONLY in whether each iteration reads one array element, while varying the
array length N:

| N | `ScanPlain` (no array) | `ScanArray` (1 read/iter) | per-read = (arr − plain)/Reps |
|---|---|---|---|
| 25 | 9.6 ms | 80.4 ms | 71 µs |
| 50 | 9.2 ms | 118.5 ms | 109 µs |
| 100 | 8.8 ms | 215.4 ms | 207 µs |
| 200 | 9.1 ms | 546.3 ms | 537 µs |
| 400 | 11.7 ms | 1119 ms | 1107 µs |

- **`ScanPlain` (pure arithmetic, no array) is FLAT across N** (~9–12 ms per 1000 iterations ≈
  ~9 µs/iter) — the interpreter's ordinary per-iteration overhead, independent of array length. This
  is *not* the bug.
- **A single `arr(idx)` read is O(N).** per-read grows ~linearly with the array length (71 µs at
  N=25 → 1.1 ms at N=400; indices sweep the whole array). Reading one `Long` from a 400-element array
  costs ~1.1 ms. This isolates the entire O(N²)-loop pathology to element access.

## Suspected mechanism (for OxVba to confirm)

Something in the vm3 element-access path is linear in array length or in surrounding state. Candidates:
- dynamic-array element access walking a descriptor / SafeArray / non-O(1) storage per index;
- module-field (`Private mX()`) resolution being non-constant per access inside a loop;
- no caching / strength-reduction of repeated `arr(i)` within an interpreted loop iteration.

## Ask

Make dynamic-array element access **O(1)** so array loops are **O(N)**. Target: a 100-element,
6-array-read loop should be sub-millisecond on the interpreter (it is ~µs natively), not 130 ms.

## Why this matters / impact

This gates OxForms's move of the control reducer/interaction layer into VBA (memory
`oxforms-reducer-home-decision`) and the hit-test architecture decision
(`docs/specs/HIT_TEST_AND_MESSAGE_LOOP_OFFLOAD.md`): with O(N²) array loops, *no* VBA-side hit-test
(even a spatial-index one) is viable, and more broadly any VBA hot path that touches arrays is
unusable. It almost certainly affects other vm3 workloads too. **Resolved by round 2 (`30099710`) — see
the RESOLVED section above for the re-run curve.** With O(1) class-field access the VBA-side reducer
move (`oxforms-reducer-home-decision`) is unblocked, and the VBA-vs-Rust hit-test home is decidable on
merits rather than gated on perf (`oxforms-bqr`).
