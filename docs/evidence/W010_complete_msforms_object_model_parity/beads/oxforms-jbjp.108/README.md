# Indexed tab mouse events

Run 8 retains [twelve native interior clicks](native-index/observations.json) at
100/150: both headers and the bodies of TabStrip and MultiPage. All 24 event
observations match in the Rust differential. MouseDown and MouseUp now use the
public FM20 five-argument signature: Index Long, Button/Shift Integer, X/Y Single.
MouseDown sees the old Value; MouseUp sees the updated Value. TabStrip body Index
is -1; MultiPage body Index is the active page. Empty Page messages forward to
the owner using translated coordinates. Child-control clicks retain their routing.

Historical probes omitted an unused Index parameter. Current replay changes only
that declaration and retains original sources, adapted sources and both hashes;
scenario actions and independent native traces remain frozen. Old generators
retain historical output for archival replay. The live capture tools adapt new
runtime sources. Wrong native signatures still fail before Office execution.

The original 150% body points lay beyond the fixed window and yielded no events;
those target diagnostics earn no credit. The retained repeated capture uses
interior points and has no empty trace. All observations reuse hidden Excel
PID 68232, launch count one; no owner input, focus, security or registration change.

Thread desktop restoration and COM release are corrected in the server. The [final cleanup](cleanup-run8.json) records all eighteen runtime handles
closed and the one Excel stopped through its retained handle after Quit. The
worker restored its desktop and CloseDesktop succeeded, with no error 170.
Bounded helper cancellation/recovery remains broader .108 work; this bead stays open.
Fresh review checked public metadata, Index/Value timing, body forwarding and
that signature adaptation cannot change the native expected transcripts.

Run 9 adds `run_bounded_probe.py`: a retained subprocess handle bounds a helper
that attaches to the already-owned Excel. On timeout only that helper is killed
and waited for. A recorded standard-module canary returned successfully before
an intentional helper-only hang. The fresh helper verifies exact process/book,
module name/source and all original module hashes before removing the canary.
The hidden-session repeat records timeout, stopped helper and successful cleanup
in `run9-recovery-hidden`; Excel remains PID 22924, launch one, Visible=False.
The earlier `run9-recovery` diagnostic exposed Visible=True on the private desktop;
the attachment helper now explicitly resets visibility before and after probes.

The genuine planner also supplied a real VBA error-94 dialog after its helper
deadline. A dedicated fresh helper verified the owned dialog and invoked its End
button through public MSAA. Subsequent complete planner observations prove the
same Excel usable again. The dialog/source and recovery record stay under `.126`.
This proves bounded helper cancellation and these recovery cases; it does not
promise recovery from every possible Excel deadlock or arbitrary native macro.
MouseUp declarations, when present, now receive the same public-FM20 metadata
preflight as MouseDown. Tests reject omitted indexed parameters before Office.

Run 9's `cleanup-run9.json` verifies the one owned Excel stopped through its
retained handle, all 32 owned runtime identities stopped, the worker desktop
restored and the private desktop closed. No cleanup errors remain. Reused PIDs
are distinguished from the recorded owned executable identity. Offline replay
is `validate_run9_cleanup.py`; no Excel is started by this validation.
