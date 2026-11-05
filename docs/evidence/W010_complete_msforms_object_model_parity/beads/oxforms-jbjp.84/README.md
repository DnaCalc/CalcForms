# Qualify native page captures

The owned native MultiPage reports BackColor=-2147483633 (system button face),
selected page 0, two pages, caption First and no child controls. The live system
color resolves to RGB(240,240,240). Computer Use's visible native window capture
corroborates that color. Its screen origin and Windows client geometry locate
the sampled point without inferring a client border from an image.

An earlier child-composited PrintWindow result showed white at the same point.
Its complete parent capture correctly contains grey. With the identical
CalcForms image, these references report 27.26% and 9.16% differing pixels.
These numbers correct the reference; CalcForms pixels are identical. Four
compact images and `comparison.json` preserve the source images, hashes, live
facts, sampled coordinates and recalculated errors.

The command now reads live MultiPage.BackColor, resolves system colors, and
checks the center of an empty authored page. It chooses a complete captured
variant that matches, preferring the composite, or marks the pixel comparison
unverified when neither does. It does not paint expected pixels into an image.
Both captured variants remain in the raw directory. A fresh eight-case run at
100%/150% passed this qualification and equal-client checks with zero additional
Excel launches. This is a check for the observed failure, not general proof that
every owner-drawn control is faithfully captured.

The first readback incorrectly requested Page.BackColor. IPage has no such
member; the pinned FM20 facts put it on IMultiPage. That unhandled probe blocked
our lease past two minutes. Only our lock/probe/runtime were released/stopped;
its owned error dialog was dismissed and the original Excel was reused. An
outer Application.Run handler also failed to prevent the dialog. New public
probe entries therefore require a local On Error handler, validated before
module insertion. The lease now independently releases at 110 seconds (or the
input cutoff), and a guard blocks further actions after expiry. It does not
cancel the outstanding Excel call. Tests cover a waiting body, replacement-lock
ownership and refusal of unprotected probe source.

Raw diagnostics are under `C:/Work/DnaCalc/codex-runs/forms-captures/` in
`round3-textbox-fixed`, `round3-page-probe`, `round3-page-guarded` and
`round3-qualified`. The qualified run closed all eight runtimes and its authored
book, retaining Excel PID 49844 for the original session's final cleanup.
No Office security, registry or unrelated process was changed.

Fresh review checked the live/visible color, complete-image selection, exclusion
of both invalid candidates, color conversion, saved hashes, owner identity,
lease expiry and probe-handler validation. Rendering differences remain W010.
Validation: all 50 evidence checks passed, including 12 new helper checks and
recomputed image/color evidence. Production Rust/VBA is unchanged from the
196-test passing tree. Final real letter-key and Ctrl+A/Backspace input in
`round3-final-input` also returned equal original greeter handler states after
the textbox correction, with a visible empty-field caret.
