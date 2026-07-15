# FM20 type-library fact tools

This directory owns the durable, non-production tooling for
`oxforms-jbjp.2`. Nothing here is imported by the OxForms runtime.

The independently reviewed input identities live in
`pinned_typelibs.v1.json`, `pinned_w005_baseline.v1.json`, and
`expected_capture.v1.json`. The exporter refuses to traverse if the capture
runtime, source files, versions, LIBATTR, registered stdole path, legacy W005
baseline, or reviewed semantic digest differs from those pins. It uses only
public `ITypeLib`/`ITypeInfo` metadata exposed through pywin32 and reloads
stdole from the hashed registered path before traversing it.

## Commands

From the repository root:

```powershell
python tools/fm20/export_typelib_facts.py
python tools/fm20/export_typelib_facts.py --check
python tools/fm20/validate_typelib_facts.py
pwsh -File tools/evidence/Test-W010FM20TypeLibFacts.ps1 -RequireSource
```

The ordinary validator reads only committed inputs and works without pywin32.
`-RequireSource` adds live pin validation and two independent regenerations
before a byte-for-byte check against the committed FM20/stdole artifacts.
Generation completes and validates both payloads before atomically replacing
either destination.

`typelib_facts.py` is the shared model, canonical serializer, COM walker, pin
checker, W005 projector, and semantic validator. The committed unit tests also
exercise truncation, unknown high flag bits, duplicate JSON keys, and the
distinction between an absent default and an explicitly encoded null.

Generated evidence belongs only under
`docs/evidence/W010_complete_msforms_object_model_parity/beads/oxforms-jbjp.2/`.
