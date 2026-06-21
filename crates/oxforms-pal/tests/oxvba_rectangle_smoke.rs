use std::sync::{Arc, Mutex};

use oxforms_pal::{
    display_list_from_smoke_trace, render_smoke_trace_headless, w002_rectangle_fixture_diagnostics,
    w002_rectangle_fixture_display_list,
};
use oxvba_hal::callbacks::HostCallbacks;
use oxvba_host::{Engine, HostConfig, RuntimeProfileId};

const RECTANGLE_SMOKE_SOURCE: &str =
    include_str!("../../../vba/smoke/fixtures/rectangle_fillrect_smoke.bas");

#[derive(Default)]
struct SmokeCallbacks {
    debug_lines: Mutex<Vec<String>>,
}

impl SmokeCallbacks {
    fn debug_output(&self) -> Vec<String> {
        self.debug_lines.lock().expect("debug lock").clone()
    }
}

impl HostCallbacks for SmokeCallbacks {
    fn on_msg_box(&self, _prompt: &str, style: i32) -> i32 {
        style.max(1)
    }

    fn on_input_box(&self, _prompt: &str, default: &str) -> String {
        default.to_string()
    }

    fn on_status_bar(&self, _text: &str) {}

    fn on_console_print(&self, _text: &str) -> bool {
        false
    }

    fn on_console_input_line(&self) -> Option<String> {
        None
    }

    fn on_debug_print(&self, text: &str) {
        self.debug_lines
            .lock()
            .expect("debug lock")
            .push(text.to_string());
    }
}

fn headless_runtime_profile() -> RuntimeProfileId {
    if cfg!(target_os = "windows") {
        RuntimeProfileId::WindowsStdio
    } else if cfg!(target_os = "linux") {
        RuntimeProfileId::LinuxStdio
    } else if cfg!(target_os = "macos") {
        RuntimeProfileId::MacOsHeadless
    } else {
        RuntimeProfileId::NullFloor
    }
}

#[test]
fn oxvba_rectangle_smoke_reaches_pal_and_matches_rust_fixture() {
    let callbacks = Arc::new(SmokeCallbacks::default());
    let mut engine = Engine::new(HostConfig { enable_jit: false });
    engine.set_runtime_profile(headless_runtime_profile());
    engine.set_host_callbacks(Some(callbacks.clone()));

    engine
        .execute_source_with_variant_snapshot_clean(RECTANGLE_SMOKE_SOURCE)
        .expect("OxVba should execute the W002 rectangle smoke fixture");

    let emitted_lines = callbacks.debug_output();
    let observed_display_list =
        display_list_from_smoke_trace(&emitted_lines).unwrap_or_else(|err| {
            panic!(
                "OxVba rectangle smoke did not decode into an OxForms PAL display list.\n\
             error: {err}\n\
             emitted lines: {emitted_lines:#?}\n\
             expected display list: {:#?}",
                w002_rectangle_fixture_display_list()
            )
        });
    assert_eq!(
        observed_display_list,
        w002_rectangle_fixture_display_list(),
        "OxVba rectangle smoke emitted a different display list.\n\
         emitted lines: {emitted_lines:#?}\n\
         expected display list: {:#?}\n\
         observed display list: {observed_display_list:#?}",
        w002_rectangle_fixture_display_list()
    );

    let observed_render = render_smoke_trace_headless(&emitted_lines).unwrap_or_else(|err| {
        panic!(
            "OxVba rectangle smoke reached the PAL seam but did not render headlessly.\n\
             error: {err}\n\
             emitted lines: {emitted_lines:#?}\n\
             expected diagnostics: {:#?}",
            w002_rectangle_fixture_diagnostics()
        )
    });
    assert_eq!(
        observed_render.diagnostics,
        w002_rectangle_fixture_diagnostics(),
        "OxVba rectangle smoke rendered with unexpected diagnostics.\n\
         emitted lines: {emitted_lines:#?}\n\
         expected display list: {:#?}\n\
         observed display list: {observed_display_list:#?}\n\
         expected diagnostics: {:#?}\n\
         observed diagnostics: {:#?}",
        w002_rectangle_fixture_display_list(),
        w002_rectangle_fixture_diagnostics(),
        observed_render.diagnostics
    );
}
