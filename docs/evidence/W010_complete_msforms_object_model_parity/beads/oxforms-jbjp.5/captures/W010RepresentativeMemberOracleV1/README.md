# Live Excel/MSForms representative member oracle

This is a clean-room black-box observation produced from the repo-owned declarative manifest through public Excel/VBIDE automation. It contains no OxForms output and makes no OxForms behavior claim.

The runner used two directly created Excel `/safe` processes: a hidden build/export/save phase, then a fresh visible AutomationSecurity=1 execution phase. Each process was created suspended, assigned to a kill-on-close Job, verified as a Job member, and only then resumed. Exact PID/start/path/hash and raw OS command-line observations bind the later `EXCEL7`/`OBJID_NATIVEOM` automation object. A narrow suspended creation-to-Job-assignment interval remains, so this evidence does not claim atomic creation-time Job association; functional tests prove descendant termination after completed launch and on abrupt supervisor death.

Each phase closed the sole allowed pathless startup workbook and recorded three exact-process isolation checkpoints covering all owned top-level windows, foreign workbooks, startup paths, Protected View, Excel AddIns/AddIns2, and loaded XLLs. Application.COMAddIns returned exact 0x800A03EC at one or more safe-mode isolation checkpoints; its inventory is incomplete and this capture makes no COM-add-in connection-state claim.

Exact member errors remain worksheet/result rows. The PNG is a coordinate-based CopyFromScreen observation with an exact selected-window/process metadata bracket immediately before and after the screen read; it requires visual review and is not proof of an HWND-owned surface. The staged tree was checksum-complete and replay-validated before atomic promotion.

The synchronous VBA run was bounded by a separate exact-PID/start-time/executable watchdog and the retained Job is the final process-tree cleanup backstop. A successful capture preserves a disarmed watchdog log; a timeout terminates only that verified private Excel process and cannot be promoted as evidence.
