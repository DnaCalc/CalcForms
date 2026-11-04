# Real shortcut input

The real workbook greeter runs on Windows/VM3 and the same owned Excel PID 49844
(one Excel launch in run 3). Physical pointer clicks and Ctrl+A use Computer
Use under desktop.lock, with a fresh observation for each action. Its
`type_text("Lin")` inserts through OS clipboard/Ctrl+V, as the runtime trace
records; this evidence does not claim three individual character keystrokes.

Before the correction, Ctrl+A produced a correct KeyDown(65, Shift=2), then
an unwanted CharacterInput("a"), replacing the selected "Ada". The preserved
`before-runtime.txt` shows that fault. Winit documents that KeyEvent.text
ignores Control. The Windows backend now consumes text_with_all_modifiers(),
so Ctrl+A's U+0001 is removed by the existing control-character filter.
Printable AltGr text remains eligible; the headless regression checks both.

`after-runtime.txt` shows select-all without the extra character, followed by
the real paste of Lin. `comparison.json` records equal original-handler state
for an Ada button click, the corrected replacement probe, and the final
Lin/button/checkbox/uppercase sequence. Four compact client references show
the replacement and final states. The final full original-handler logs agree:
Initialize, Change:Lin, Click:Hello, Lin, Check:True, Click:HELLO, LIN.

These are separate probes, not one six-row continuous input recording. The
native owned form appears as a secondary window of the Excel app to Computer
Use. Sending keys to the root after the button receives focus can activate the
worksheet; such attempts are excluded from keyboard parity credit. The input
diagnostics remain under codex-runs/forms-captures/round3. No unrelated window
was operated, and all foreground/input calls took the shared lock.

Fresh review inspected the actual key and paste trace rather than treating
type_text as per-character typing. Stale focus/caret pixels discovered by the
final clicks are separate follow-up work; this keyboard fix does not claim
rendering parity, exhaustive accelerators, drag behavior or full W010 parity.
