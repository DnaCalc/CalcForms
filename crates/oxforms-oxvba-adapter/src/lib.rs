//! OxVba-facing PAL adapter for OxForms.
//!
//! This is deliberately smoke-only. It proves the D2 integration shape from the
//! spec: the OxForms VBA library obtains an injected COM-like PAL object and
//! calls flat, value-typed drawing members that Rust can also expose through a
//! C ABI later.
//!
//! This crate is the only W002 layer that depends on OxVba. The core PAL crate
//! remains host/runtime independent.

use std::sync::{Arc, Mutex};

use oxvba_com::{
    platform::portable::{PortableDispatch, PortableObjectFactory},
    PortableComProjection,
};
use oxvba_runtime::Variant;

use oxforms_pal::{
    render_headless, Color, DisplayCommand, DisplayList, HeadlessRender, Rect, SurfaceSize,
};

/// ProgID used by the W002 smoke fixture through `CreateObject`.
pub const SMOKE_CANVAS_PROG_ID: &str = "OxForms.SmokeCanvas";

/// Factory registered into OxVba's portable COM projection for W002 smoke tests.
#[derive(Debug, Default)]
pub struct SmokeCanvasFactory {
    state: Arc<Mutex<SmokeCanvasState>>,
}

impl SmokeCanvasFactory {
    #[must_use]
    pub fn new() -> Self {
        Self::default()
    }

    pub fn snapshot(&self) -> Result<SmokeCanvasSnapshot, String> {
        let state = self
            .state
            .lock()
            .map_err(|_| "smoke canvas state lock poisoned".to_string())?;
        Ok(SmokeCanvasSnapshot {
            display_list: state.display_list.clone(),
            rendered: state.rendered.clone(),
            calls: state.calls.clone(),
        })
    }
}

impl PortableObjectFactory for SmokeCanvasFactory {
    fn create(&self) -> Box<dyn PortableDispatch> {
        Box::new(SmokeCanvasDispatch {
            state: self.state.clone(),
        })
    }
}

/// Register the smoke canvas ProgID in an OxVba portable COM projection.
pub fn register_smoke_canvas(projection: &PortableComProjection, factory: Arc<SmokeCanvasFactory>) {
    projection.register_object(SMOKE_CANVAS_PROG_ID, factory);
}

/// Captured Rust-side evidence after the VBA fixture runs.
#[derive(Clone, Debug, Default, Eq, PartialEq)]
pub struct SmokeCanvasSnapshot {
    pub display_list: Option<DisplayList>,
    pub rendered: Option<HeadlessRender>,
    pub calls: Vec<String>,
}

#[derive(Clone, Debug, Default, Eq, PartialEq)]
struct SmokeCanvasState {
    display_list: Option<DisplayList>,
    rendered: Option<HeadlessRender>,
    calls: Vec<String>,
}

struct SmokeCanvasDispatch {
    state: Arc<Mutex<SmokeCanvasState>>,
}

impl PortableDispatch for SmokeCanvasDispatch {
    fn invoke(&self, member: &str, args: &[Variant]) -> Result<Variant, String> {
        let member = canonical_member(member)
            .ok_or_else(|| format!("unexpected {SMOKE_CANVAS_PROG_ID} method `{member}`"))?;
        self.record_call(member, args.len())?;

        match member {
            "CreateSurface" => self.create_surface(args),
            "FillRect" => self.fill_rect(args),
            "Flush" => self.flush(args),
            _ => unreachable!("canonical_member filters methods"),
        }
    }

    fn get(&self, member: &str) -> Result<Variant, String> {
        Err(format!(
            "unexpected {SMOKE_CANVAS_PROG_ID} property get `{member}`"
        ))
    }

    fn put(&self, member: &str, _value: Variant) -> Result<(), String> {
        Err(format!(
            "unexpected {SMOKE_CANVAS_PROG_ID} property put `{member}`"
        ))
    }

    fn member_names(&self) -> Vec<String> {
        vec!["CreateSurface".into(), "FillRect".into(), "Flush".into()]
    }
}

impl SmokeCanvasDispatch {
    fn create_surface(&self, args: &[Variant]) -> Result<Variant, String> {
        expect_arg_count("CreateSurface", args, 2)?;
        let width = u32_arg("CreateSurface", args, 0, "width")?;
        let height = u32_arg("CreateSurface", args, 1, "height")?;

        let mut state = self.lock_state()?;
        state.display_list = Some(DisplayList::new(SurfaceSize::new(width, height)));
        state.rendered = None;

        Ok(Variant::empty())
    }

    fn fill_rect(&self, args: &[Variant]) -> Result<Variant, String> {
        expect_arg_count("FillRect", args, 8)?;
        let rect = Rect::new(
            i32_arg("FillRect", args, 0, "x")?,
            i32_arg("FillRect", args, 1, "y")?,
            i32_arg("FillRect", args, 2, "width")?,
            i32_arg("FillRect", args, 3, "height")?,
        );
        let color = Color::rgba(
            u8_arg("FillRect", args, 4, "red")?,
            u8_arg("FillRect", args, 5, "green")?,
            u8_arg("FillRect", args, 6, "blue")?,
            u8_arg("FillRect", args, 7, "alpha")?,
        );

        let mut state = self.lock_state()?;
        let display_list = state
            .display_list
            .as_mut()
            .ok_or_else(|| "FillRect called before CreateSurface".to_string())?;
        display_list
            .commands
            .push(DisplayCommand::FillRect { rect, color });
        state.rendered = None;

        Ok(Variant::empty())
    }

    fn flush(&self, args: &[Variant]) -> Result<Variant, String> {
        expect_arg_count("Flush", args, 0)?;
        let display_list = {
            let state = self.lock_state()?;
            state
                .display_list
                .clone()
                .ok_or_else(|| "Flush called before CreateSurface".to_string())?
        };
        let rendered = render_headless(&display_list)
            .map_err(|err| format!("{SMOKE_CANVAS_PROG_ID}.Flush render failed: {err}"))?;
        let command_count = i32::try_from(rendered.diagnostics.command_count)
            .map_err(|_| "Flush command count exceeded VBA Long range".to_string())?;

        let mut state = self.lock_state()?;
        state.rendered = Some(rendered);

        Ok(Variant::from_i32(command_count))
    }

    fn record_call(&self, member: &str, arg_count: usize) -> Result<(), String> {
        let mut state = self.lock_state()?;
        state.calls.push(format!("{member}:{arg_count}"));
        Ok(())
    }

    fn lock_state(&self) -> Result<std::sync::MutexGuard<'_, SmokeCanvasState>, String> {
        self.state
            .lock()
            .map_err(|_| "smoke canvas state lock poisoned".to_string())
    }
}

fn canonical_member(member: &str) -> Option<&'static str> {
    if member.eq_ignore_ascii_case("CreateSurface") {
        Some("CreateSurface")
    } else if member.eq_ignore_ascii_case("FillRect") {
        Some("FillRect")
    } else if member.eq_ignore_ascii_case("Flush") {
        Some("Flush")
    } else {
        None
    }
}

fn expect_arg_count(member: &str, args: &[Variant], expected: usize) -> Result<(), String> {
    if args.len() == expected {
        Ok(())
    } else {
        Err(format!(
            "{SMOKE_CANVAS_PROG_ID}.{member} expected {expected} argument(s), got {}",
            args.len()
        ))
    }
}

fn i32_arg(member: &str, args: &[Variant], index: usize, name: &str) -> Result<i32, String> {
    args.get(index).and_then(Variant::as_i32).ok_or_else(|| {
        format!(
            "{SMOKE_CANVAS_PROG_ID}.{member} expected argument {} `{name}` as VBA Long, got {:?}",
            index + 1,
            args.get(index)
        )
    })
}

fn u32_arg(member: &str, args: &[Variant], index: usize, name: &str) -> Result<u32, String> {
    let value = i32_arg(member, args, index, name)?;
    u32::try_from(value).map_err(|_| {
        format!(
            "{SMOKE_CANVAS_PROG_ID}.{member} expected argument {} `{name}` to be non-negative, got {value}",
            index + 1
        )
    })
}

fn u8_arg(member: &str, args: &[Variant], index: usize, name: &str) -> Result<u8, String> {
    let value = i32_arg(member, args, index, name)?;
    u8::try_from(value).map_err(|_| {
        format!(
            "{SMOKE_CANVAS_PROG_ID}.{member} expected argument {} `{name}` in 0..=255, got {value}",
            index + 1
        )
    })
}
