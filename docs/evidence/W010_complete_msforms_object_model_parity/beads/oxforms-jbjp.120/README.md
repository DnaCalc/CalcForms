# Exact process cleanup during image startup or exit

The required member-oracle watchdog suite reproduced a StrictMode null
MainModule/FileName failure during immediate cleanup of a disposable process.
Cleanup now obtains the executable path with QueryFullProcessImageNameW from
the retained process handle, alongside exact creation time and PID. A confirmed
exit requires no kill; live identity read errors and mismatches still refuse
cleanup. No broad process-name termination is used.

The real immediate-child test requires the kernel path to equal the owned path.
Existing mismatched creation/path, containment membership, abrupt supervisor
exit, watchdog deadlines and exact termination checks remain required. The full
member-oracle check passes, including the unchanged containment-ready deadline;
no timeout was relaxed or check skipped. This test starts disposable helpers,
not Excel. Fresh review verified that the catch path never authorizes a kill.
