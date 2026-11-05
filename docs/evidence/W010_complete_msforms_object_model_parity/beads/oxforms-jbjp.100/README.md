# Native text capture qualification

The interrupted 150% composite contains only the upper Label/TextBox and an
empty button. Its parent contains lower controls but omits Disabled's caption.
With no background probes the old algorithm accepted both. The new replay
rejects both complete images: five composite text regions are missing, and the
parent fails Disabled. No image pixels were repaired or combined across attempts.

Live capture reads actual native Caption/Text/List/Tabs/Pages values, Visible
and Enabled from the shown form's Controls collection. Every nonempty visible
root text region must have ink in its recorded ROI. Selected white and disabled
grey text qualify; straight borders and dotted focus are excluded. Native child
origins, individual missing glyphs and every list row are outside this presence
check and retain their separate parity coverage failures.

`reference.json` retains native facts, actual text sources, ROIs, ink counts,
image hashes and candidate results. All four forms at both scales qualify:
5/7/8/3 root regions in greeter/common/selection/containers respectively.
For the interrupted image, geometry comes from that attempt's facts; text values
are independently read from the same authored corpus in the new owned Excel.
Only Clipped's height differs (30pt versus 12pt), and its ROI uses the saved
30pt measurement. `validate_text_capture_reference.py` replays every result.

New native owner: one Excel launch, PID 20232, private desktop
CalcFormsOracle_c8f782743d07. It is hidden from the input desktop; no desktop
switch, foreground-window call, Computer Use, pointer/keyboard input, security
or registration changes. The same process remains owned for subsequent work.
The capture helper tests, historical background/Frame replays, eight new clients,
the interrupted case, and intrinsic layout/parity replays pass. Fresh review
keeps native reads inside the desktop lease for the existing interactive path
and checks that matching backgrounds or border ink cannot qualify the blanks.
