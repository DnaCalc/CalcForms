//! CalcVBA-facing adapters for CalcForms.
//!
//! This crate contains host-runtime glue only. It translates CalcVBA
//! `PortableDispatch` and `Variant` calls into typed `calcforms-pal` contracts.
//! The core `calcforms-pal` crate must not depend on this crate or on CalcVBA.
//!
//! It projects `CalcForms.Surface` (the retained-Scene seam VBA forms self-render
//! through) and drives the runtime effect/render loop.

#![forbid(unsafe_code)]

pub mod host_services;
mod library;
pub mod office;
pub mod runtime;
pub mod surface;

/// The embedded VBA runtime library, for hosts compiling an authored application.
/// Office forms and source-form hosts must use this same module roster.
pub fn library_modules() -> Vec<calcvba_symbol::manifest::ModuleUnit> {
    library::modules()
}
