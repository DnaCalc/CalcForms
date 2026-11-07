# FORMS PARITY: 1,203 pass / 415 fail; 346 missing measurements

Frame background MouseDown previously reached the reducer's callback but the
callback was empty and no public event existed. Frame now declares the exact
public FM20 signature (Button/Shift Integer, X/Y Single) and raises that event.
The two retained native Group hit-testing observations now match at 100/150.

The Frame regression subscribes through WithEvents and requires all four local
scalar arguments. Child hits still reach the child; a point outside the child's
clip reaches only the Frame background. Existing tab/focus/clip assertions remain.
This adds MouseDown coverage; other Frame event breadth remains W010 work.

Eighteen production behavior/input/keyboard scenarios were re-executed from the
same archived scenario sources. The paired report has exactly two measured gains
and zero regressions against `.129`. Every earlier native fact and image stays
unchanged. Pixels remain a coarse guard. The source census is now 842 public
declarations and 115 public events; the full-library ledger remains red at
2,452 verified / 4,682 gaps / 622 unexpected-public rows.

`frame_mouse_reference.py` checks raw FM20 parameter metadata, source and runtime
hashes, complete row regeneration and unchanged native observations. Fresh review
checked event subscription, payload shape, local coordinates, child isolation,
remaining root-form hit failures and fixture tab-index questions (`.131/.132`).
