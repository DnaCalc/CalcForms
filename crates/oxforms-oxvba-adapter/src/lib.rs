//! OxVba-facing adapters for OxForms.
//!
//! This crate contains host-runtime glue only. It translates OxVba
//! `PortableDispatch` and `Variant` calls into typed `oxforms-pal` contracts.
//! The core `oxforms-pal` crate must not depend on this crate or on OxVba.
//!
//! Current implementation surface is limited to the W002 smoke canvas proof.

#![forbid(unsafe_code)]

pub mod event_dispatch;
pub mod runtime_runner;
pub mod smoke_canvas;
pub mod surface;
