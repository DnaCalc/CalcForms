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

Thread desktop restoration and COM release are corrected in the server. Final
CloseDesktop cleanup remains to be observed before this run ends; bounded helper
cancellation/recovery remains broader .108 work. This bead stays open.
Fresh review checked public metadata, Index/Value timing, body forwarding and
that signature adaptation cannot change the native expected transcripts.
