//! Deterministic headless runner for the VBA-reducer CalcForms runtime.
//!
//! This crate is test/profiling infrastructure over the real runtime path:
//! [`OxRuntime`] drives the VBA form-document, [`SurfaceFactory`] captures the
//! resident `Scene`, and `calcforms-pal` remains the renderer. The runner adds only
//! scriptable input, drain/repaint policy, a virtual clock, and structured trace
//! rows so headless tests and visible backends exercise the same contract.

use std::path::{Path, PathBuf};
use std::sync::Arc;
use std::time::Instant;

use calcforms_calcvba_adapter::host_services::{
    HostCursor, HostServices, HostTimerRequest, HostTimerSlot,
};
use calcforms_calcvba_adapter::runtime::{
    OxRuntime, RuntimeInput, RuntimeKeyKind, RuntimeMouseKind, RuntimePhaseTiming,
};
use calcforms_calcvba_adapter::surface::{register_surface, SurfaceFactory, SurfaceSnapshot};
use calcforms_pal::scene::StubShaper;
use calcvba_bundle::ProjectMemberKind;
use calcvba_com::PortableComProjection;
use calcvba_engine::{Engine, HostConfig, HostProfileProvider, ProjectRuntimeSession};
use calcvba_hal::model::HostPolicy;
use calcvba_runtime::Variant;
use calcvba_symbol::manifest::{
    ModuleAttributes, ModuleKind, ModuleUnit, ProjectKind, SymbolProjectManifest,
};
use serde::Serialize;

pub const SHIFT_SHIFT: i16 = 1;
pub const SHIFT_CTRL: i16 = 2;
pub const SHIFT_ALT: i16 = 4;

pub const VK_BACKSPACE: i16 = 8;
pub const VK_TAB: i16 = 9;
pub const VK_ENTER: i16 = 13;
pub const VK_ESCAPE: i16 = 27;
pub const VK_SPACE: i16 = 32;
pub const VK_END: i16 = 35;
pub const VK_HOME: i16 = 36;
pub const VK_LEFT: i16 = 37;
pub const VK_UP: i16 = 38;
pub const VK_RIGHT: i16 = 39;
pub const VK_DOWN: i16 = 40;
pub const VK_DELETE: i16 = 46;
pub const VK_V: i16 = 86;

#[derive(Clone, Copy, Debug, Default, Eq, PartialEq)]
pub enum RepaintPolicy {
    Manual,
    AfterEachDispatch,
    #[default]
    AfterNonEmptyEffect,
    VisibleBootstrap,
}

#[derive(Clone, Debug)]
pub struct RunnerOptions {
    pub project_name: String,
    pub repaint_policy: RepaintPolicy,
}

impl Default for RunnerOptions {
    fn default() -> Self {
        Self {
            project_name: "CalcFormsHeadless".to_string(),
            repaint_policy: RepaintPolicy::default(),
        }
    }
}

#[derive(Clone, Debug)]
pub struct FixtureModule {
    pub name: String,
    pub kind: ModuleKind,
    pub relative_path: PathBuf,
}

impl FixtureModule {
    #[must_use]
    pub fn class(name: &str, relative_path: impl Into<PathBuf>) -> Self {
        Self {
            name: name.to_string(),
            kind: ModuleKind::Class,
            relative_path: relative_path.into(),
        }
    }

    #[must_use]
    pub fn procedural(name: &str, relative_path: impl Into<PathBuf>) -> Self {
        Self {
            name: name.to_string(),
            kind: ModuleKind::Procedural,
            relative_path: relative_path.into(),
        }
    }
}

#[derive(Clone, Debug)]
pub struct FormSpec {
    pub form_class: String,
    pub build_member: String,
    pub fixtures: Vec<FixtureModule>,
}

impl FormSpec {
    #[must_use]
    pub fn new(form_class: &str, build_member: &str) -> Self {
        Self {
            form_class: form_class.to_string(),
            build_member: build_member.to_string(),
            fixtures: Vec::new(),
        }
    }

    #[must_use]
    pub fn with_fixture(mut self, fixture: FixtureModule) -> Self {
        self.fixtures.push(fixture);
        self
    }
}

#[derive(Clone, Debug)]
pub enum InputAction {
    MouseDown {
        x: i32,
        y: i32,
        button: i16,
        shift: i16,
    },
    MouseMove {
        x: i32,
        y: i32,
        button: i16,
        shift: i16,
    },
    MouseUp {
        x: i32,
        y: i32,
        button: i16,
        shift: i16,
    },
    KeyDown {
        key_code: i16,
        shift: i16,
    },
    KeyUp {
        key_code: i16,
        shift: i16,
    },
    CharacterInput(String),
    PasteText(String),
    DropText(String),
    HostServiceProbe,
    SetCursor(HostCursor),
    ArmTimer(HostTimerRequest),
    CancelTimer(HostTimerSlot),
    DecodeImage {
        image_id: String,
        bytes_sha256: String,
    },
    DpiChanged {
        dpi_x: u32,
        dpi_y: u32,
    },
    Tick {
        advance_ms: u64,
    },
    Render,
}

impl InputAction {
    #[must_use]
    pub fn char(text: &str) -> Self {
        Self::CharacterInput(text.to_string())
    }

    #[must_use]
    pub fn key_turn(key_code: i16, text: &str) -> Vec<Self> {
        vec![
            Self::KeyDown { key_code, shift: 0 },
            Self::CharacterInput(text.to_string()),
            Self::KeyUp { key_code, shift: 0 },
        ]
    }
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum DrainPolicy {
    One,
    All,
}

#[derive(Clone, Debug, Default, Serialize)]
pub struct TraceRow {
    pub seq: u64,
    pub at_ms: u64,
    pub action: String,
    pub effect_log: String,
    pub host_service_effects: Vec<String>,
    pub accessibility_snapshot: String,
    pub render_revision: u64,
    pub frame_token: Option<u64>,
    pub node_count: usize,
    pub dispatch_us: u128,
    pub render_us: u128,
    pub snapshot_us: u128,
    pub runtime_phase_timings: Vec<RuntimePhaseTrace>,
    pub surface_call_timings: Vec<SurfaceCallTrace>,
    pub surface_rust_us: u128,
}

#[derive(Clone, Debug, Default, Serialize)]
pub struct RuntimePhaseTrace {
    pub name: String,
    pub elapsed_us: u128,
}

#[derive(Clone, Debug, Default, Serialize)]
pub struct SurfaceCallTrace {
    pub call: String,
    pub member: String,
    pub arg_count: usize,
    pub elapsed_us: u128,
    pub ok: bool,
}

#[derive(Clone, Debug, Default)]
pub struct DispatchReport {
    pub effects: String,
    pub service_effects: Vec<String>,
    pub rendered: bool,
    pub revision: u64,
    pub frame_token: Option<u64>,
    pub node_count: usize,
    pub snapshot_us: u128,
    pub runtime_phase_timings: Vec<RuntimePhaseTrace>,
    pub surface_call_timings: Vec<SurfaceCallTrace>,
    pub surface_rust_us: u128,
}

pub struct HeadlessRunner {
    rt: OxRuntime,
    surface: Arc<SurfaceFactory>,
    options: RunnerOptions,
    clock_ms: u64,
    seq: u64,
    trace: Vec<TraceRow>,
}

impl HeadlessRunner {
    pub fn attach(repo_root: &Path, spec: &FormSpec) -> Result<Self, String> {
        Self::attach_with_options(repo_root, spec, RunnerOptions::default())
    }

    pub fn attach_with_options(
        repo_root: &Path,
        spec: &FormSpec,
        options: RunnerOptions,
    ) -> Result<Self, String> {
        let (session, surface) = build_session(repo_root, spec, &options)?;
        let rt = OxRuntime::attach_with_host_services(
            session,
            &spec.form_class,
            &spec.build_member,
            HostServices::headless(),
        )?;
        Ok(Self {
            rt,
            surface,
            options,
            clock_ms: 0,
            seq: 0,
            trace: Vec::new(),
        })
    }

    pub fn dispatch(&mut self, action: InputAction) -> Result<DispatchReport, String> {
        let surface_timing_start = self.surface.call_timing_count()?;
        let dispatch_start = Instant::now();
        if let InputAction::Tick { advance_ms } = &action {
            self.clock_ms = self.clock_ms.saturating_add(*advance_ms);
        }
        let runtime_input = runtime_input_for_action(&action);
        let (action_label, effects, service_effects, repainted_in_dispatch, runtime_phase_timings) =
            match runtime_input {
                Some(input) => {
                    let turn = self.rt.dispatch_event_turn(input)?;
                    (
                        turn.action,
                        turn.effect_log,
                        turn.host_service_effects,
                        turn.repainted,
                        runtime_phase_trace(turn.phase_timings),
                    )
                }
                None => match &action {
                    InputAction::Render => (
                        "render".to_string(),
                        String::new(),
                        Vec::new(),
                        false,
                        Vec::new(),
                    ),
                    _ => unreachable!("runtime_input_for_action covers dispatched input"),
                },
            };
        let dispatch_us = dispatch_start.elapsed().as_micros();

        let needs_runner_render = match self.options.repaint_policy {
            RepaintPolicy::Manual => action_label == "render",
            RepaintPolicy::AfterEachDispatch => !repainted_in_dispatch,
            RepaintPolicy::AfterNonEmptyEffect => {
                !repainted_in_dispatch && (!effects.is_empty() || action_label == "render")
            }
            RepaintPolicy::VisibleBootstrap => {
                !repainted_in_dispatch
                    && (action_label == "render"
                        || (!effects.is_empty() && !is_deferred_plain_text_key_action(&action)))
            }
        };
        let rendered = repainted_in_dispatch || needs_runner_render;

        let render_start = Instant::now();
        if needs_runner_render {
            self.rt.render()?;
        }
        let render_us = if needs_runner_render {
            render_start.elapsed().as_micros()
        } else {
            0
        };

        let snapshot_start = Instant::now();
        let snap = self.surface.snapshot()?;
        let snapshot_us = snapshot_start.elapsed().as_micros();
        let surface_call_timings: Vec<SurfaceCallTrace> = snap
            .call_timings
            .iter()
            .skip(surface_timing_start)
            .map(surface_call_trace)
            .collect();
        let surface_rust_us = surface_call_timings
            .iter()
            .filter(|call| !call.member.starts_with("ProfileMark."))
            .map(|call| call.elapsed_us)
            .sum();
        let report = DispatchReport {
            effects: effects.clone(),
            service_effects: service_effects.clone(),
            rendered,
            revision: snap.revision,
            frame_token: snap.frame_token,
            node_count: snap.node_count,
            snapshot_us,
            runtime_phase_timings: runtime_phase_timings.clone(),
            surface_call_timings: surface_call_timings.clone(),
            surface_rust_us,
        };
        let accessibility_snapshot = self.try_read_accessibility_snapshot();
        self.seq += 1;
        self.trace.push(TraceRow {
            seq: self.seq,
            at_ms: self.clock_ms,
            action: action_label,
            effect_log: effects,
            host_service_effects: service_effects,
            accessibility_snapshot,
            render_revision: snap.revision,
            frame_token: snap.frame_token,
            node_count: snap.node_count,
            dispatch_us,
            render_us,
            snapshot_us,
            runtime_phase_timings,
            surface_call_timings,
            surface_rust_us,
        });
        Ok(report)
    }

    pub fn drain(
        &mut self,
        script: &mut Vec<InputAction>,
        policy: DrainPolicy,
    ) -> Result<Vec<DispatchReport>, String> {
        let limit = match policy {
            DrainPolicy::One => script.len().min(1),
            DrainPolicy::All => script.len(),
        };
        let actions: Vec<InputAction> = script.drain(0..limit).collect();
        actions
            .into_iter()
            .map(|action| self.dispatch(action))
            .collect()
    }

    pub fn render(&mut self) -> Result<(), String> {
        self.dispatch(InputAction::Render).map(|_| ())
    }

    pub fn snapshot(&self) -> Result<SurfaceSnapshot, String> {
        self.surface.snapshot()
    }

    #[must_use]
    pub fn trace(&self) -> &[TraceRow] {
        &self.trace
    }

    pub fn trace_jsonl(&self) -> Result<String, String> {
        let mut out = String::new();
        for row in &self.trace {
            let line = serde_json::to_string(row)
                .map_err(|err| format!("serialize headless trace row: {err}"))?;
            out.push_str(&line);
            out.push('\n');
        }
        Ok(out)
    }

    pub fn invoke_string(
        &mut self,
        member: &str,
        kind: ProjectMemberKind,
    ) -> Result<String, String> {
        Ok(self
            .invoke(member, kind)?
            .as_bstr()
            .map(|s| s.as_str())
            .unwrap_or_default())
    }

    pub fn read_string(&mut self, member: &str) -> Result<String, String> {
        self.invoke_string(member, ProjectMemberKind::PropertyGet)
    }

    pub fn read_i32(&mut self, member: &str) -> Result<i32, String> {
        self.invoke(member, ProjectMemberKind::PropertyGet)?
            .as_i32()
            .ok_or_else(|| format!("{member} did not return a Long-compatible value"))
    }

    pub fn read_bool(&mut self, member: &str) -> Result<bool, String> {
        self.invoke(member, ProjectMemberKind::PropertyGet)?
            .as_bool()
            .ok_or_else(|| format!("{member} did not return a Boolean"))
    }

    fn invoke(&mut self, member: &str, kind: ProjectMemberKind) -> Result<Variant, String> {
        let form = self.rt.form();
        self.rt
            .session_mut()
            .invoke_member_values(form, member, Some(kind), Vec::new())
            .map_err(|err| format!("invoke {member}: {}", err.message()))
    }

    fn try_read_accessibility_snapshot(&mut self) -> String {
        self.invoke_string("AccessibilitySnapshot", ProjectMemberKind::PropertyGet)
            .unwrap_or_default()
    }
}

fn runtime_phase_trace(phases: Vec<RuntimePhaseTiming>) -> Vec<RuntimePhaseTrace> {
    phases
        .into_iter()
        .map(|phase| RuntimePhaseTrace {
            name: phase.name,
            elapsed_us: phase.elapsed_us,
        })
        .collect()
}

fn surface_call_trace(
    call: &calcforms_calcvba_adapter::surface::SurfaceCallTiming,
) -> SurfaceCallTrace {
    SurfaceCallTrace {
        call: call.label(),
        member: call.member.clone(),
        arg_count: call.arg_count,
        elapsed_us: call.elapsed_us,
        ok: call.ok,
    }
}

fn runtime_input_for_action(action: &InputAction) -> Option<RuntimeInput> {
    match action {
        InputAction::MouseDown {
            x,
            y,
            button,
            shift,
        } => Some(RuntimeInput::Mouse {
            kind: RuntimeMouseKind::Down,
            x: *x,
            y: *y,
            button: *button,
            shift: *shift,
        }),
        InputAction::MouseMove {
            x,
            y,
            button,
            shift,
        } => Some(RuntimeInput::Mouse {
            kind: RuntimeMouseKind::Move,
            x: *x,
            y: *y,
            button: *button,
            shift: *shift,
        }),
        InputAction::MouseUp {
            x,
            y,
            button,
            shift,
        } => Some(RuntimeInput::Mouse {
            kind: RuntimeMouseKind::Up,
            x: *x,
            y: *y,
            button: *button,
            shift: *shift,
        }),
        InputAction::KeyDown { key_code, shift } => Some(RuntimeInput::Key {
            kind: RuntimeKeyKind::Down,
            key_code: *key_code,
            shift: *shift,
        }),
        InputAction::KeyUp { key_code, shift } => Some(RuntimeInput::Key {
            kind: RuntimeKeyKind::Up,
            key_code: *key_code,
            shift: *shift,
        }),
        InputAction::CharacterInput(text) => Some(RuntimeInput::CharacterInput(text.clone())),
        InputAction::PasteText(text) => Some(RuntimeInput::PasteText(text.clone())),
        InputAction::DropText(text) => Some(RuntimeInput::DropText(text.clone())),
        InputAction::HostServiceProbe => Some(RuntimeInput::ServiceProbe),
        InputAction::SetCursor(cursor) => Some(RuntimeInput::SetCursor(*cursor)),
        InputAction::ArmTimer(request) => Some(RuntimeInput::ArmTimer(request.clone())),
        InputAction::CancelTimer(slot) => Some(RuntimeInput::CancelTimer(slot.clone())),
        InputAction::DecodeImage {
            image_id,
            bytes_sha256,
        } => Some(RuntimeInput::DecodeImage {
            image_id: image_id.clone(),
            bytes_sha256: bytes_sha256.clone(),
        }),
        InputAction::DpiChanged { dpi_x, dpi_y } => Some(RuntimeInput::DpiChanged {
            dpi_x: *dpi_x,
            dpi_y: *dpi_y,
        }),
        InputAction::Tick { advance_ms } => Some(RuntimeInput::AdvanceTime {
            advance_ms: *advance_ms,
        }),
        InputAction::Render => None,
    }
}

fn is_deferred_plain_text_key_action(action: &InputAction) -> bool {
    match action {
        InputAction::KeyDown { key_code, shift } | InputAction::KeyUp { key_code, shift } => {
            (*shift & (SHIFT_CTRL | SHIFT_ALT)) == 0
                && (matches!(*key_code, VK_SPACE)
                    || (48..=57).contains(key_code)
                    || (65..=90).contains(key_code))
        }
        _ => false,
    }
}

pub fn repo_root_from_crate() -> PathBuf {
    Path::new(env!("CARGO_MANIFEST_DIR")).join("..").join("..")
}

fn build_session(
    repo_root: &Path,
    spec: &FormSpec,
    options: &RunnerOptions,
) -> Result<(ProjectRuntimeSession, Arc<SurfaceFactory>), String> {
    let mut modules = calcforms_modules(repo_root)?;
    for fixture in &spec.fixtures {
        modules.push(module_unit(
            repo_root,
            &fixture.name,
            fixture.kind,
            &fixture.relative_path,
        )?);
    }

    let manifest = SymbolProjectManifest {
        project_name: options.project_name.clone(),
        project_kind: ProjectKind::Library,
        modules,
        references: Vec::new(),
        reference_projects: Vec::new(),
        conditional_constants: Default::default(),
        conditional_compilation_target: Default::default(),
    };

    let program = calcvba_bind::bind_program(&manifest, &calcvba_symbol::CatalogTypeLibResolver)
        .map_err(|err| format!("bind headless project: {err:?}"))?;
    let bundle = calcvba_oxir::elaborate::elaborate(&program)
        .map_err(|err| format!("elaborate headless project: {err:?}"))?;

    let projection = Arc::new(PortableComProjection::new());
    let surface = Arc::new(SurfaceFactory::with_shaper(Arc::new(StubShaper)));
    register_surface(&projection, surface.clone());

    let profile = HostProfileProvider::new()
        .with_portable_com_projection(projection)
        .with_host_policy(HostPolicy::native());
    let engine = Engine::new(HostConfig::vm3()).with_host_profile_provider(profile);
    let session = engine
        .prepare_image_session(calcvba_oxir::OxImage::new(vec![bundle]))
        .map_err(|err| format!("prepare headless session: {err:?}"))?;
    Ok((session, surface))
}

fn calcforms_modules(repo_root: &Path) -> Result<Vec<ModuleUnit>, String> {
    use ModuleKind::{Class, Procedural};
    let modules = [
        (
            "CalcFormsModel",
            Procedural,
            "vba/calcforms/CalcFormsModel.bas",
        ),
        ("IOxControl", Class, "vba/calcforms/IOxControl.cls"),
        ("IOxControlHost", Class, "vba/calcforms/IOxControlHost.cls"),
        (
            "IOxControlContainer",
            Class,
            "vba/calcforms/IOxControlContainer.cls",
        ),
        ("OxControlCore", Class, "vba/calcforms/OxControlCore.cls"),
        ("Controls", Class, "vba/calcforms/Controls.cls"),
        ("ReturnInteger", Class, "vba/calcforms/ReturnInteger.cls"),
        ("ReturnBoolean", Class, "vba/calcforms/ReturnBoolean.cls"),
        ("Font", Class, "vba/calcforms/Font.cls"),
        ("Label", Class, "vba/calcforms/Label.cls"),
        ("OxTextService", Class, "vba/calcforms/OxTextService.cls"),
        ("TextBox", Class, "vba/calcforms/TextBox.cls"),
        ("CommandButton", Class, "vba/calcforms/CommandButton.cls"),
        ("CheckBox", Class, "vba/calcforms/CheckBox.cls"),
        ("ListBox", Class, "vba/calcforms/ListBox.cls"),
        ("ComboBox", Class, "vba/calcforms/ComboBox.cls"),
        ("Frame", Class, "vba/calcforms/Frame.cls"),
        ("Image", Class, "vba/calcforms/Image.cls"),
        ("MultiPage", Class, "vba/calcforms/MultiPage.cls"),
        ("Page", Class, "vba/calcforms/Page.cls"),
        ("Pages", Class, "vba/calcforms/Pages.cls"),
        ("SpinButton", Class, "vba/calcforms/SpinButton.cls"),
        ("ScrollBar", Class, "vba/calcforms/ScrollBar.cls"),
        ("Tab", Class, "vba/calcforms/Tab.cls"),
        ("Tabs", Class, "vba/calcforms/Tabs.cls"),
        ("TabStrip", Class, "vba/calcforms/TabStrip.cls"),
        ("ToggleButton", Class, "vba/calcforms/ToggleButton.cls"),
        (
            "OptionButtonControl",
            Class,
            "vba/calcforms/OptionButtonControl.cls",
        ),
        ("UserForm", Class, "vba/calcforms/UserForm.cls"),
        ("OxTheme", Procedural, "vba/calcforms/OxTheme.bas"),
        (
            "OxControlPaint",
            Procedural,
            "vba/calcforms/OxControlPaint.bas",
        ),
        ("OxSceneBuilder", Class, "vba/calcforms/OxSceneBuilder.cls"),
        (
            "OxAccessibilityService",
            Class,
            "vba/calcforms/OxAccessibilityService.cls",
        ),
        (
            "OxInteractionManager",
            Class,
            "vba/calcforms/OxInteractionManager.cls",
        ),
        ("OxReducer", Class, "vba/calcforms/OxReducer.cls"),
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
