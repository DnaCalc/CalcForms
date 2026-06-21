# VBA Smoke Projects

This directory contains on-disk `.basproj` fixtures that OxVba loads through
`oxvba_project::load_project_closure`.

The W002 rectangle app fixture is intentionally split from the OxForms library so
the smoke proves the intended ownership direction: app project -> OxForms VBA
library -> Rust PAL renderer.
