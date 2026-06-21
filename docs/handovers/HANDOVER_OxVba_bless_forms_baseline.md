Status: Open
Target: OxVba
Ask: Bless or tag an OxForms development baseline at `501bf64d978afd14b820ebd03096f9fdcc247e38` or a newer equivalent commit after current local OxVba work is reconciled.
Context: OxForms should not depend on a floating `../OxVba` checkout because OxVba is under active development. The latest release tag, `v0.1.2`, is 2081 commits behind the observed `origin/master`, while the workspace package version still reports `0.1.2`.
Evidence: Observed OxVba baseline on 2026-06-21: `master == origin/master == 501bf64d978afd14b820ebd03096f9fdcc247e38` (`Harden COM runtime object transport`). `MODPROJ-030` remains `planned` / `forms-deferred`, so OxForms will also need coordinated form-module integration closure work.
