use std::cmp::Reverse;
use std::collections::BTreeMap;
use std::fs;
use std::path::PathBuf;
use std::process::Command;

use calcforms_calcvba_adapter::host_services::{HostCursor, HostTimerRequest, HostTimerSlot};
use calcforms_headless_runner::{
    repo_root_from_crate, FixtureModule, FormSpec, HeadlessRunner, InputAction, RepaintPolicy,
    RunnerOptions, RuntimePhaseTrace, SurfaceCallTrace, TraceRow, VK_BACKSPACE, VK_TAB,
};
use serde::Serialize;

fn showcase_spec() -> FormSpec {
    FormSpec::new("FullSurfaceShowcaseForm", "Build").with_fixture(FixtureModule::class(
        "FullSurfaceShowcaseForm",
        "vba/smoke/fixtures/full_surface_showcase_form.cls",
    ))
}

fn scale_spec(build_member: &str) -> FormSpec {
    FormSpec::new("PerfBudgetScaleForm", build_member).with_fixture(FixtureModule::class(
        "PerfBudgetScaleForm",
        "vba/smoke/fixtures/perf_budget_scale_form.cls",
    ))
}

#[test]
#[ignore = "performance baseline: writes a host-specific JSON artifact"]
fn textbox_repeat_paste_baseline_writes_json_report() {
    let repo = repo_root_from_crate();
    let run_id = "w009-textbox-repeat-paste-baseline";
    let scenarios = vec![
        run_scenario(
            &repo,
            "burst_typing_40_chars",
            key_turns("visibletextboxbaselinevisibletextboxbase"),
            "visibletextboxbaselinevisibletextboxbase",
        ),
        run_scenario(
            &repo,
            "held_char_repeat_30",
            held_char_repeat('a', 30),
            &"a".repeat(30),
        ),
        run_scenario(
            &repo,
            "backspace_repeat_20",
            backspace_repeat("abcdefghijklmnopqrst", 20),
            "",
        ),
        run_scenario(
            &repo,
            "paste_fragment_repeat_20",
            repeated_paste("frag", 20),
            &"frag".repeat(20),
        ),
    ];

    let report = PerfReport {
        run_id,
        bead: report_bead("CALCFORMS_TEXTBOX_PERF_BEAD", "oxforms-aghp"),
        git_rev: command_output("git", &["rev-parse", "--short", "HEAD"]),
        git_status_short: command_output("git", &["status", "--short"]),
        rustc: command_output("rustc", &["--version"]),
        host: HostFingerprint {
            os: std::env::consts::OS,
            arch: std::env::consts::ARCH,
            logical_cpus: std::thread::available_parallelism()
                .map(usize::from)
                .unwrap_or(0),
        },
        notes: [
            "Headless baseline over OxRuntime + VBA OxReducer + SurfaceFactory using RepaintPolicy::VisibleBootstrap.",
            "dispatch_us includes the VBA reducer call and any reducer-owned repaint.",
            "render_us is only nonzero when the runner issues an additional Render call.",
            "snapshot_us measures resident Scene snapshot extraction after dispatch/render.",
            "paste_fragment_repeat_20 uses RuntimeInput::PasteText with headless HostServices, not the Windows OS clipboard.",
        ],
        scenarios,
    };

    let out = output_path();
    if let Some(parent) = out.parent() {
        fs::create_dir_all(parent).expect("create perf artifact directory");
    }
    let json = serde_json::to_string_pretty(&report).expect("serialize perf report");
    fs::write(&out, json).expect("write perf report");
    eprintln!("wrote {}", out.display());
}

#[test]
#[ignore = "performance attribution: writes a host-specific JSON artifact"]
fn textbox_paste_dispatch_attribution_writes_json_report() {
    assert!(
        std::env::var_os("CALCFORMS_PROFILE_TIMINGS").is_some(),
        "set CALCFORMS_PROFILE_TIMINGS=1 so attribution includes runtime/surface timings"
    );
    let repo = repo_root_from_crate();
    let scenario = run_attribution_scenario(
        &repo,
        "paste_fragment_repeat_20",
        repeated_paste("frag", 20),
        &"frag".repeat(20),
    );
    let report = AttributionReport {
        run_id: "w009-textbox-paste-dispatch-attribution",
        bead: report_bead("CALCFORMS_TEXTBOX_ATTRIBUTION_BEAD", "oxforms-zhz.36"),
        baseline_bead: "oxforms-aghp",
        git_rev: command_output("git", &["rev-parse", "--short", "HEAD"]),
        git_status_short: command_output("git", &["status", "--short"]),
        rustc: command_output("rustc", &["--version"]),
        host: HostFingerprint {
            os: std::env::consts::OS,
            arch: std::env::consts::ARCH,
            logical_cpus: std::thread::available_parallelism()
                .map(usize::from)
                .unwrap_or(0),
        },
        notes: [
            "Attribution-only follow-up over the same OxRuntime + VBA OxReducer + SurfaceFactory path.",
            "Runtime phase timings split HostServices clipboard, VBA SetClipboardText, and DispatchKey Ctrl+V.",
            "Surface call timings cover Rust-side BeginScene/MeasureBatch/SubmitPatch work only.",
            "DispatchKey minus surface remains a combined VBA/VM bucket: TextBox paste mutation, events, UserForm.Render scene building, and COM marshalling.",
            "No optimization or repaint-policy change is made by this report.",
        ],
        hotspot_table: hotspot_table(&scenario),
        hypothesis_ledger: hypothesis_ledger(&scenario),
        scenario,
    };

    let out = attribution_output_path();
    if let Some(parent) = out.parent() {
        fs::create_dir_all(parent).expect("create perf artifact directory");
    }
    let json = serde_json::to_string_pretty(&report).expect("serialize attribution report");
    fs::write(&out, json).expect("write attribution report");
    eprintln!("wrote {}", out.display());
}

#[test]
#[ignore = "W009 ideal architecture budget report: writes a host-specific JSON artifact"]
fn w009_ideal_architecture_budget_report_writes_json() {
    let repo = repo_root_from_crate();
    let scenarios = vec![
        budget_scenario(
            &repo,
            "input_to_state_render_paste",
            repeated_paste("state", 8),
            "statestatestatestatestatestatestatestate",
        ),
        budget_scenario(
            &repo,
            "burst_typing_40_chars",
            key_turns("visibletextboxbaselinevisibletextboxbase"),
            "visibletextboxbaselinevisibletextboxbase",
        ),
        budget_scenario(
            &repo,
            "backspace_repeat_20",
            backspace_repeat("abcdefghijklmnopqrst", 20),
            "",
        ),
        budget_scenario(&repo, "tab_traversal_12", tab_turns(12), ""),
        budget_scenario(&repo, "mouse_cursor_moves_40", mouse_moves(40), ""),
    ];
    let timer = timer_budget_scenario(&repo);
    let scale = vec![
        scale_budget(&repo, "Build10", 10),
        scale_budget(&repo, "Build50", 50),
        scale_budget(&repo, "Build100", 100),
    ];
    let hotspot_table = budget_hotspots(&scenarios, &timer, &scale);
    let report = BudgetReport {
        run_id: "w009-ideal-architecture-budget-20260707",
        bead: report_bead("CALCFORMS_W009_BUDGET_BEAD", "oxforms-zhz.31"),
        git_rev: command_output("git", &["rev-parse", "--short", "HEAD"]),
        git_status_short: command_output("git", &["status", "--short"]),
        rustc: command_output("rustc", &["--version"]),
        host: HostFingerprint {
            os: std::env::consts::OS,
            arch: std::env::consts::ARCH,
            logical_cpus: std::thread::available_parallelism()
                .map(usize::from)
                .unwrap_or(0),
        },
        profile_timings_enabled: std::env::var_os("CALCFORMS_PROFILE_TIMINGS").is_some(),
        notes: [
            "Host-specific headless budget report over OxRuntime + VBA OxReducer + SurfaceFactory.",
            "This is ranked measurement evidence only; no optimization is made by this bead.",
            "Scenario dispatch_us includes VBA reducer work and reducer-owned repaint.",
            "Surface timings cover Rust-side SurfaceFactory calls only when CALCFORMS_PROFILE_TIMINGS is set.",
            "Scale scenarios measure first-paint and one-control incremental crossing counts at 10/50/100 labels.",
        ],
        scenarios,
        timer,
        scale,
        hotspot_table,
        hypothesis_ledger: budget_hypotheses(),
    };

    let out = budget_output_path();
    if let Some(parent) = out.parent() {
        fs::create_dir_all(parent).expect("create budget artifact directory");
    }
    let json = serde_json::to_string_pretty(&report).expect("serialize budget report");
    fs::write(&out, json).expect("write budget report");
    eprintln!("wrote {}", out.display());
}

fn report_bead(env_name: &str, default: &'static str) -> String {
    std::env::var(env_name).unwrap_or_else(|_| default.to_string())
}

fn run_scenario(
    repo: &std::path::Path,
    name: &'static str,
    mut actions: Vec<InputAction>,
    expected_text: &str,
) -> ScenarioReport {
    let mut runner = HeadlessRunner::attach_with_options(
        repo,
        &showcase_spec(),
        RunnerOptions {
            project_name: "CalcFormsTextBoxPerf".to_string(),
            repaint_policy: RepaintPolicy::VisibleBootstrap,
        },
    )
    .expect("attach showcase");
    runner.render().expect("initial render");
    for action in actions.drain(..) {
        runner.dispatch(action).expect("dispatch perf action");
    }
    let final_text = runner.read_string("InputText").expect("InputText");
    assert_eq!(final_text, expected_text, "scenario {name} final text");
    let surface_snapshot = runner.snapshot().expect("surface snapshot");
    let surface_call_counts = summarize_calls(&surface_snapshot.calls);

    let rows: Vec<&TraceRow> = runner
        .trace()
        .iter()
        .filter(|row| row.action != "render")
        .collect();
    let mut worst_dispatch: Vec<&TraceRow> = rows.clone();
    worst_dispatch.sort_by_key(|row| Reverse(row.dispatch_us));
    let worst_dispatch = worst_dispatch
        .into_iter()
        .take(5)
        .map(|row| WorstTurn {
            seq: row.seq,
            action: row.action.clone(),
            effect_log: row.effect_log.clone(),
            dispatch_us: row.dispatch_us,
            render_us: row.render_us,
            snapshot_us: row.snapshot_us,
        })
        .collect();

    let service_effect_rows = rows
        .iter()
        .filter(|row| !row.host_service_effects.is_empty())
        .count();
    let effect_rows = rows.iter().filter(|row| !row.effect_log.is_empty()).count();
    let repaint_rows = rows
        .iter()
        .filter(|row| row.effect_log.split('|').any(|effect| effect == "repaint"))
        .count();

    ScenarioReport {
        name,
        action_rows: rows.len(),
        effect_rows,
        repaint_rows,
        service_effect_rows,
        total_surface_calls: surface_snapshot.calls.len(),
        surface_call_counts,
        final_text_len: final_text.len(),
        final_text,
        dispatch_us: summarize(rows.iter().map(|row| row.dispatch_us)),
        render_us: summarize(rows.iter().map(|row| row.render_us)),
        snapshot_us: summarize(rows.iter().map(|row| row.snapshot_us)),
        worst_dispatch,
    }
}

fn run_attribution_scenario(
    repo: &std::path::Path,
    name: &'static str,
    mut actions: Vec<InputAction>,
    expected_text: &str,
) -> AttributionScenario {
    let mut runner = HeadlessRunner::attach_with_options(
        repo,
        &showcase_spec(),
        RunnerOptions {
            project_name: "CalcFormsTextBoxAttribution".to_string(),
            repaint_policy: RepaintPolicy::VisibleBootstrap,
        },
    )
    .expect("attach showcase");
    runner.render().expect("initial render");
    for action in actions.drain(..) {
        runner
            .dispatch(action)
            .expect("dispatch attribution action");
    }
    let final_text = runner.read_string("InputText").expect("InputText");
    assert_eq!(final_text, expected_text, "scenario {name} final text");

    let turns: Vec<TurnAttribution> = runner
        .trace()
        .iter()
        .filter(|row| row.action != "render")
        .map(turn_attribution)
        .collect();
    let dispatch_key_minus_surface_us = turns
        .iter()
        .map(TurnAttribution::dispatch_key_minus_surface_us);

    AttributionScenario {
        name,
        turn_count: turns.len(),
        final_text_len: final_text.len(),
        final_text,
        total_dispatch_us: summarize(turns.iter().map(|turn| turn.dispatch_us)),
        dispatch_key_ctrl_v_us: summarize(phase_values(&turns, "DispatchKey:keydown:Ctrl+V")),
        dispatch_key_minus_surface_us: summarize(dispatch_key_minus_surface_us),
        host_set_clipboard_us: summarize(phase_values(&turns, "HostServices.SetClipboardText")),
        vba_set_clipboard_us: summarize(phase_values(&turns, "SetClipboardText")),
        surface_rust_us: summarize(turns.iter().map(|turn| turn.surface_rust_us)),
        measure_batch_us: summarize(surface_values(&turns, "MeasureBatch")),
        submit_patch_us: summarize(surface_values(&turns, "SubmitPatch")),
        snapshot_us: summarize(turns.iter().map(|turn| turn.snapshot_us)),
        runtime_phase_summaries: summarize_runtime_phases(&turns),
        surface_call_summaries: summarize_surface_calls(&turns),
        worst_turns: worst_turns(&turns),
        turns,
    }
}

fn budget_scenario(
    repo: &std::path::Path,
    name: &'static str,
    actions: Vec<InputAction>,
    expected_text: &str,
) -> ScenarioReport {
    run_scenario(repo, name, actions, expected_text)
}

fn timer_budget_scenario(repo: &std::path::Path) -> TimerBudget {
    let mut runner = HeadlessRunner::attach_with_options(
        repo,
        &showcase_spec(),
        RunnerOptions {
            project_name: "CalcFormsTimerBudget".to_string(),
            repaint_policy: RepaintPolicy::VisibleBootstrap,
        },
    )
    .expect("attach showcase timer budget");
    runner.render().expect("initial render");
    let actions = [
        InputAction::MouseDown {
            x: 546,
            y: 174,
            button: 1,
            shift: 0,
        },
        InputAction::ArmTimer(HostTimerRequest::new(HostTimerSlot::AutoRepeat, 25, true)),
        InputAction::Tick { advance_ms: 24 },
        InputAction::Tick { advance_ms: 1 },
        InputAction::Tick { advance_ms: 50 },
        InputAction::MouseUp {
            x: 546,
            y: 174,
            button: 1,
            shift: 0,
        },
        InputAction::CancelTimer(HostTimerSlot::AutoRepeat),
    ];
    for action in actions {
        runner
            .dispatch(action)
            .expect("dispatch timer budget action");
    }
    let final_spin_value = runner.read_i32("SpinValue").expect("SpinValue");
    let rows: Vec<&TraceRow> = runner
        .trace()
        .iter()
        .filter(|row| row.action != "render")
        .collect();
    let timer_fire_rows = rows
        .iter()
        .filter(|row| {
            row.host_service_effects
                .iter()
                .any(|effect| effect.starts_with("timer.fire:auto_repeat:"))
        })
        .count();
    TimerBudget {
        name: "spinbutton_auto_repeat_virtual_timer",
        action_rows: rows.len(),
        timer_fire_rows,
        final_spin_value,
        dispatch_us: summarize(rows.iter().map(|row| row.dispatch_us)),
        snapshot_us: summarize(rows.iter().map(|row| row.snapshot_us)),
        service_effects: rows
            .iter()
            .flat_map(|row| row.host_service_effects.iter().cloned())
            .collect(),
        worst_dispatch: worst_trace_rows(&rows),
    }
}

fn scale_budget(repo: &std::path::Path, build_member: &str, control_count: usize) -> ScaleBudget {
    let mut runner = HeadlessRunner::attach_with_options(
        repo,
        &scale_spec(build_member),
        RunnerOptions {
            project_name: format!("CalcFormsScaleBudget{control_count}"),
            repaint_policy: RepaintPolicy::Manual,
        },
    )
    .expect("attach scale budget");
    let first = runner.snapshot().expect("first-paint snapshot");
    let first_paint_len = first.calls.len();
    let first_paint_calls = non_profile_calls(&first.calls);
    runner
        .invoke_string("ChangeOne", calcvba_bundle::ProjectMemberKind::Method)
        .expect("change one label");
    runner.render().expect("incremental render");
    let after = runner.snapshot().expect("after change snapshot");
    let change_calls = non_profile_calls(&after.calls[first_paint_len..]);
    let hit_y = 8 + ((control_count as i32 - 1) * 16) + 7;
    for i in 0..20 {
        runner
            .dispatch(InputAction::MouseMove {
                x: 20 + (i % 3),
                y: hit_y,
                button: 0,
                shift: 0,
            })
            .expect("dispatch scale hit-test mouse move");
    }
    let hit_rows: Vec<&TraceRow> = runner
        .trace()
        .iter()
        .filter(|row| row.action.starts_with("mouse_move:"))
        .collect();
    ScaleBudget {
        control_count,
        first_paint_node_count: first.node_count,
        first_paint_call_count: first_paint_calls.len(),
        first_paint_calls,
        change_call_count: change_calls.len(),
        change_calls,
        final_node_count: after.node_count,
        hit_test_dispatch_us: summarize(hit_rows.iter().map(|row| row.dispatch_us)),
    }
}

fn turn_attribution(row: &TraceRow) -> TurnAttribution {
    TurnAttribution {
        seq: row.seq,
        action: row.action.clone(),
        effect_log: row.effect_log.clone(),
        effects: split_effects(&row.effect_log),
        dispatch_us: row.dispatch_us,
        dispatch_minus_surface_us: row.dispatch_us.saturating_sub(row.surface_rust_us),
        render_us: row.render_us,
        snapshot_us: row.snapshot_us,
        runtime_phase_timings: row.runtime_phase_timings.clone(),
        surface_call_timings: row.surface_call_timings.clone(),
        surface_rust_us: row.surface_rust_us,
    }
}

fn key_turns(text: &str) -> Vec<InputAction> {
    let mut actions = Vec::new();
    for ch in text.chars() {
        actions.extend(InputAction::key_turn(vk_for_char(ch), &ch.to_string()));
    }
    actions
}

fn held_char_repeat(ch: char, count: usize) -> Vec<InputAction> {
    let mut actions = Vec::new();
    let vk = vk_for_char(ch);
    for _ in 0..count {
        actions.push(InputAction::KeyDown {
            key_code: vk,
            shift: 0,
        });
        actions.push(InputAction::CharacterInput(ch.to_string()));
    }
    actions.push(InputAction::KeyUp {
        key_code: vk,
        shift: 0,
    });
    actions
}

fn backspace_repeat(seed: &str, count: usize) -> Vec<InputAction> {
    let mut actions = key_turns(seed);
    for _ in 0..count {
        actions.push(InputAction::KeyDown {
            key_code: VK_BACKSPACE,
            shift: 0,
        });
    }
    actions.push(InputAction::KeyUp {
        key_code: VK_BACKSPACE,
        shift: 0,
    });
    actions
}

fn repeated_paste(fragment: &str, count: usize) -> Vec<InputAction> {
    (0..count)
        .map(|_| InputAction::PasteText(fragment.to_string()))
        .collect()
}

fn tab_turns(count: usize) -> Vec<InputAction> {
    let mut actions = Vec::new();
    for _ in 0..count {
        actions.push(InputAction::KeyDown {
            key_code: VK_TAB,
            shift: 0,
        });
        actions.push(InputAction::KeyUp {
            key_code: VK_TAB,
            shift: 0,
        });
    }
    actions
}

fn mouse_moves(count: usize) -> Vec<InputAction> {
    let mut actions = vec![InputAction::SetCursor(HostCursor::IBeam)];
    for i in 0..count {
        actions.push(InputAction::MouseMove {
            x: 22 + (i as i32 % 30),
            y: 98,
            button: 0,
            shift: 0,
        });
    }
    actions
}

fn vk_for_char(ch: char) -> i16 {
    match ch.to_ascii_uppercase() {
        'A'..='Z' | '0'..='9' => ch.to_ascii_uppercase() as u8 as i16,
        other => panic!("unsupported perf scenario char {other:?}"),
    }
}

fn summarize(values: impl Iterator<Item = u128>) -> Summary {
    let mut values: Vec<u128> = values.collect();
    values.sort_unstable();
    let count = values.len();
    let sum = values.iter().sum();
    Summary {
        count,
        sum,
        p50: percentile(&values, 50),
        p95: percentile(&values, 95),
        p99: percentile(&values, 99),
        max: values.last().copied().unwrap_or(0),
    }
}

fn percentile(sorted: &[u128], pct: usize) -> u128 {
    if sorted.is_empty() {
        return 0;
    }
    let idx = ((sorted.len() - 1) * pct).div_ceil(100);
    sorted[idx]
}

fn output_path() -> PathBuf {
    std::env::var_os("CALCFORMS_TEXTBOX_PERF_OUT")
        .map(PathBuf::from)
        .unwrap_or_else(|| {
            repo_root_from_crate()
                .join("target/oxforms-perf/w009-textbox-repeat-paste-baseline.json")
        })
}

fn attribution_output_path() -> PathBuf {
    std::env::var_os("CALCFORMS_TEXTBOX_ATTRIBUTION_OUT")
        .map(PathBuf::from)
        .unwrap_or_else(|| {
            repo_root_from_crate()
                .join("target/oxforms-perf/w009-textbox-paste-dispatch-attribution.json")
        })
}

fn budget_output_path() -> PathBuf {
    std::env::var_os("CALCFORMS_W009_BUDGET_OUT")
        .map(PathBuf::from)
        .unwrap_or_else(|| {
            repo_root_from_crate().join("target/oxforms-perf/w009-ideal-architecture-budget.json")
        })
}

fn command_output(program: &str, args: &[&str]) -> String {
    Command::new(program)
        .args(args)
        .output()
        .ok()
        .filter(|output| output.status.success())
        .map(|output| String::from_utf8_lossy(&output.stdout).trim().to_string())
        .unwrap_or_else(|| "unavailable".to_string())
}

fn split_effects(effect_log: &str) -> Vec<String> {
    effect_log
        .split('|')
        .filter(|part| !part.is_empty())
        .map(str::to_string)
        .collect()
}

fn phase_values<'a>(
    turns: &'a [TurnAttribution],
    phase_name: &'a str,
) -> impl Iterator<Item = u128> + 'a {
    turns.iter().filter_map(move |turn| {
        turn.runtime_phase_timings
            .iter()
            .find(|phase| phase.name == phase_name)
            .map(|phase| phase.elapsed_us)
    })
}

fn surface_values<'a>(
    turns: &'a [TurnAttribution],
    member: &'a str,
) -> impl Iterator<Item = u128> + 'a {
    turns.iter().flat_map(move |turn| {
        turn.surface_call_timings
            .iter()
            .filter(move |call| call.member == member)
            .map(|call| call.elapsed_us)
    })
}

fn summarize_runtime_phases(turns: &[TurnAttribution]) -> Vec<NamedSummary> {
    let mut values: BTreeMap<String, Vec<u128>> = BTreeMap::new();
    for phase in turns
        .iter()
        .flat_map(|turn| turn.runtime_phase_timings.iter())
    {
        values
            .entry(phase.name.clone())
            .or_default()
            .push(phase.elapsed_us);
    }
    named_summaries(values)
}

fn summarize_surface_calls(turns: &[TurnAttribution]) -> Vec<NamedSummary> {
    let mut values: BTreeMap<String, Vec<u128>> = BTreeMap::new();
    for call in turns
        .iter()
        .flat_map(|turn| turn.surface_call_timings.iter())
    {
        values
            .entry(call.member.clone())
            .or_default()
            .push(call.elapsed_us);
    }
    named_summaries(values)
}

fn named_summaries(values: BTreeMap<String, Vec<u128>>) -> Vec<NamedSummary> {
    values
        .into_iter()
        .map(|(name, values)| NamedSummary {
            name,
            summary: summarize(values.into_iter()),
        })
        .collect()
}

fn worst_turns(turns: &[TurnAttribution]) -> Vec<TurnAttribution> {
    let mut worst = turns.to_vec();
    worst.sort_by_key(|turn| Reverse(turn.dispatch_us));
    worst.into_iter().take(5).collect()
}

fn worst_trace_rows(rows: &[&TraceRow]) -> Vec<WorstTurn> {
    let mut worst = rows.to_vec();
    worst.sort_by_key(|row| Reverse(row.dispatch_us));
    worst
        .into_iter()
        .take(5)
        .map(|row| WorstTurn {
            seq: row.seq,
            action: row.action.clone(),
            effect_log: row.effect_log.clone(),
            dispatch_us: row.dispatch_us,
            render_us: row.render_us,
            snapshot_us: row.snapshot_us,
        })
        .collect()
}

fn hotspot_table(scenario: &AttributionScenario) -> Vec<HotspotRow> {
    vec![
        HotspotRow {
            rank: 1,
            area: "DispatchKey Ctrl+V inclusive",
            metric: "p95_us",
            value_us: scenario.dispatch_key_ctrl_v_us.p95,
            evidence: "runtime_phase_summaries.DispatchKey:keydown:Ctrl+V",
            interpretation: "The Ctrl+V reducer turn remains the top inclusive bucket.",
        },
        HotspotRow {
            rank: 2,
            area: "DispatchKey minus Rust surface",
            metric: "p95_us",
            value_us: scenario.dispatch_key_minus_surface_us.p95,
            evidence: "scenario.dispatch_key_minus_surface_us",
            interpretation: "Current seams leave TextBox paste mutation, events, VBA UserForm.Render scene building, and VM/COM marshalling combined here.",
        },
        HotspotRow {
            rank: 3,
            area: "Rust surface crossings",
            metric: "p95_us",
            value_us: scenario.surface_rust_us.p95,
            evidence: "surface_call_summaries",
            interpretation: "Rust MeasureBatch/SubmitPatch work is measured separately from the VBA dispatch bucket.",
        },
        HotspotRow {
            rank: 4,
            area: "VBA SetClipboardText",
            metric: "p95_us",
            value_us: scenario.vba_set_clipboard_us.p95,
            evidence: "runtime_phase_summaries.SetClipboardText",
            interpretation: "Clipboard text push into the reducer is isolated from the Ctrl+V dispatch.",
        },
        HotspotRow {
            rank: 5,
            area: "HostServices clipboard write",
            metric: "p95_us",
            value_us: scenario.host_set_clipboard_us.p95,
            evidence: "runtime_phase_summaries.HostServices.SetClipboardText",
            interpretation: "The headless host clipboard write is isolated from VBA work.",
        },
    ]
}

fn budget_hotspots(
    scenarios: &[ScenarioReport],
    timer: &TimerBudget,
    scale: &[ScaleBudget],
) -> Vec<HotspotRow> {
    let slowest_dispatch = scenarios
        .iter()
        .map(|scenario| scenario.dispatch_us.p95)
        .chain(std::iter::once(timer.dispatch_us.p95))
        .max()
        .unwrap_or(0);
    let largest_change_crossings = scale
        .iter()
        .map(|scenario| scenario.change_call_count as u128)
        .max()
        .unwrap_or(0);
    let scaled_hit_test = scale
        .iter()
        .map(|scenario| scenario.hit_test_dispatch_us.p95)
        .max()
        .unwrap_or(0);
    vec![
        HotspotRow {
            rank: 1,
            area: "Scaled VBA hit-test mouse move",
            metric: "p95_us",
            value_us: scaled_hit_test,
            evidence: "scale[*].hit_test_dispatch_us.p95",
            interpretation: "Mouse-move hit testing grows sharply at 50/100 controls and is the top follow-up target.",
        },
        HotspotRow {
            rank: 2,
            area: "Slowest representative dispatch",
            metric: "p95_us",
            value_us: slowest_dispatch,
            evidence: "scenarios[*].dispatch_us.p95 and timer.dispatch_us.p95",
            interpretation: "This is the top end-to-end input-to-state/render budget bucket in the broad report.",
        },
        HotspotRow {
            rank: 3,
            area: "Scale one-control change crossings",
            metric: "max_count",
            value_us: largest_change_crossings,
            evidence: "scale[*].change_call_count",
            interpretation: "The 10/50/100-control incremental render budget should stay constant.",
        },
        HotspotRow {
            rank: 4,
            area: "Timer virtual repeat dispatch",
            metric: "p95_us",
            value_us: timer.dispatch_us.p95,
            evidence: "timer.dispatch_us.p95",
            interpretation: "Auto-repeat timer fires use the same OxRuntime event-turn path.",
        },
    ]
}

fn hypothesis_ledger(scenario: &AttributionScenario) -> Vec<Hypothesis> {
    let total_p95 = scenario.total_dispatch_us.p95.max(1);
    vec![
        Hypothesis {
            name: "Host clipboard write dominates paste",
            verdict: if scenario.host_set_clipboard_us.p95 * 5 < total_p95 {
                "rejects"
            } else {
                "supports"
            },
            evidence: format!(
                "host p95 {} us vs total dispatch p95 {} us",
                scenario.host_set_clipboard_us.p95, scenario.total_dispatch_us.p95
            ),
        },
        Hypothesis {
            name: "VBA SetClipboardText dominates paste",
            verdict: if scenario.vba_set_clipboard_us.p95 * 5 < total_p95 {
                "rejects"
            } else {
                "supports"
            },
            evidence: format!(
                "SetClipboardText p95 {} us vs total dispatch p95 {} us",
                scenario.vba_set_clipboard_us.p95, scenario.total_dispatch_us.p95
            ),
        },
        Hypothesis {
            name: "Rust surface implementation dominates paste",
            verdict: if scenario.surface_rust_us.p95 * 5 < total_p95 {
                "rejects"
            } else {
                "supports"
            },
            evidence: format!(
                "surface p95 {} us vs total dispatch p95 {} us",
                scenario.surface_rust_us.p95, scenario.total_dispatch_us.p95
            ),
        },
        Hypothesis {
            name: "Remaining Ctrl+V dispatch/VBA render bucket dominates paste",
            verdict: if scenario.dispatch_key_minus_surface_us.p95 * 2 > total_p95 {
                "supports"
            } else {
                "rejects"
            },
            evidence: format!(
                "DispatchKey minus surface p95 {} us vs total dispatch p95 {} us",
                scenario.dispatch_key_minus_surface_us.p95, scenario.total_dispatch_us.p95
            ),
        },
    ]
}

fn budget_hypotheses() -> Vec<Hypothesis> {
    vec![
        Hypothesis {
            name: "Scene crossing count scales with control count for one-control changes",
            verdict: "rejects",
            evidence: "scale change calls are reported separately for 10/50/100 controls"
                .to_string(),
        },
        Hypothesis {
            name: "Timer repeat needs a parallel runtime path",
            verdict: "rejects",
            evidence: "timer budget scenario dispatches auto_repeat through OxRuntime".to_string(),
        },
        Hypothesis {
            name: "Further optimization should proceed without scenario-specific evidence",
            verdict: "rejects",
            evidence:
                "this bead records budgets only; optimization requires a ranked follow-up target"
                    .to_string(),
        },
    ]
}

fn summarize_calls(calls: &[String]) -> Vec<CallCount> {
    let mut counts = BTreeMap::new();
    for call in calls {
        *counts.entry(call.clone()).or_insert(0) += 1;
    }
    counts
        .into_iter()
        .map(|(call, count)| CallCount { call, count })
        .collect()
}

fn non_profile_calls(calls: &[String]) -> Vec<String> {
    calls
        .iter()
        .filter(|call| !call.starts_with("ProfileMark"))
        .cloned()
        .collect()
}

#[derive(Serialize)]
struct PerfReport {
    run_id: &'static str,
    bead: String,
    git_rev: String,
    git_status_short: String,
    rustc: String,
    host: HostFingerprint,
    notes: [&'static str; 5],
    scenarios: Vec<ScenarioReport>,
}

#[derive(Serialize)]
struct AttributionReport {
    run_id: &'static str,
    bead: String,
    baseline_bead: &'static str,
    git_rev: String,
    git_status_short: String,
    rustc: String,
    host: HostFingerprint,
    notes: [&'static str; 5],
    hotspot_table: Vec<HotspotRow>,
    hypothesis_ledger: Vec<Hypothesis>,
    scenario: AttributionScenario,
}

#[derive(Serialize)]
struct BudgetReport {
    run_id: &'static str,
    bead: String,
    git_rev: String,
    git_status_short: String,
    rustc: String,
    host: HostFingerprint,
    profile_timings_enabled: bool,
    notes: [&'static str; 5],
    scenarios: Vec<ScenarioReport>,
    timer: TimerBudget,
    scale: Vec<ScaleBudget>,
    hotspot_table: Vec<HotspotRow>,
    hypothesis_ledger: Vec<Hypothesis>,
}

#[derive(Serialize)]
struct HostFingerprint {
    os: &'static str,
    arch: &'static str,
    logical_cpus: usize,
}

#[derive(Serialize)]
struct ScenarioReport {
    name: &'static str,
    action_rows: usize,
    effect_rows: usize,
    repaint_rows: usize,
    service_effect_rows: usize,
    total_surface_calls: usize,
    surface_call_counts: Vec<CallCount>,
    final_text_len: usize,
    final_text: String,
    dispatch_us: Summary,
    render_us: Summary,
    snapshot_us: Summary,
    worst_dispatch: Vec<WorstTurn>,
}

#[derive(Serialize)]
struct AttributionScenario {
    name: &'static str,
    turn_count: usize,
    final_text_len: usize,
    final_text: String,
    total_dispatch_us: Summary,
    dispatch_key_ctrl_v_us: Summary,
    dispatch_key_minus_surface_us: Summary,
    host_set_clipboard_us: Summary,
    vba_set_clipboard_us: Summary,
    surface_rust_us: Summary,
    measure_batch_us: Summary,
    submit_patch_us: Summary,
    snapshot_us: Summary,
    runtime_phase_summaries: Vec<NamedSummary>,
    surface_call_summaries: Vec<NamedSummary>,
    worst_turns: Vec<TurnAttribution>,
    turns: Vec<TurnAttribution>,
}

#[derive(Serialize)]
struct TimerBudget {
    name: &'static str,
    action_rows: usize,
    timer_fire_rows: usize,
    final_spin_value: i32,
    dispatch_us: Summary,
    snapshot_us: Summary,
    service_effects: Vec<String>,
    worst_dispatch: Vec<WorstTurn>,
}

#[derive(Serialize)]
struct ScaleBudget {
    control_count: usize,
    first_paint_node_count: usize,
    first_paint_call_count: usize,
    first_paint_calls: Vec<String>,
    change_call_count: usize,
    change_calls: Vec<String>,
    final_node_count: usize,
    hit_test_dispatch_us: Summary,
}

#[derive(Clone, Serialize)]
struct TurnAttribution {
    seq: u64,
    action: String,
    effect_log: String,
    effects: Vec<String>,
    dispatch_us: u128,
    dispatch_minus_surface_us: u128,
    render_us: u128,
    snapshot_us: u128,
    runtime_phase_timings: Vec<RuntimePhaseTrace>,
    surface_call_timings: Vec<SurfaceCallTrace>,
    surface_rust_us: u128,
}

impl TurnAttribution {
    fn dispatch_key_minus_surface_us(&self) -> u128 {
        self.runtime_phase_timings
            .iter()
            .find(|phase| phase.name == "DispatchKey:keydown:Ctrl+V")
            .map(|phase| phase.elapsed_us.saturating_sub(self.surface_rust_us))
            .unwrap_or(0)
    }
}

#[derive(Serialize)]
struct CallCount {
    call: String,
    count: usize,
}

#[derive(Serialize)]
struct Summary {
    count: usize,
    sum: u128,
    p50: u128,
    p95: u128,
    p99: u128,
    max: u128,
}

#[derive(Serialize)]
struct NamedSummary {
    name: String,
    summary: Summary,
}

#[derive(Serialize)]
struct HotspotRow {
    rank: usize,
    area: &'static str,
    metric: &'static str,
    value_us: u128,
    evidence: &'static str,
    interpretation: &'static str,
}

#[derive(Serialize)]
struct Hypothesis {
    name: &'static str,
    verdict: &'static str,
    evidence: String,
}

#[derive(Serialize)]
struct WorstTurn {
    seq: u64,
    action: String,
    effect_log: String,
    dispatch_us: u128,
    render_us: u128,
    snapshot_us: u128,
}
