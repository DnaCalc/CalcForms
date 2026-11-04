# VBA Smoke Projects

This directory contains on-disk `.basproj` fixtures that CalcVBA loads through
`calcvba_project::load_project_closure`.

The W002 rectangle app fixture is intentionally split from the CalcForms library so
the smoke proves the intended ownership direction: app project -> CalcForms VBA
library -> Rust PAL renderer.
