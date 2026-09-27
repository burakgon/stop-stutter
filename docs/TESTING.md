# Test coverage

## Automated

`swift test` uses an in-memory interface driver and recovery journal. It never changes networking, invokes sudo, or registers a daemon.

The suite covers writing only when the interface is in the wrong state, OS reactivation corrected on events and heartbeats, bounded verification retries, the per-session revival count, expired-lease accounting, idle detection for updates, multiple independent leases, immediate disconnect recovery, heartbeat renewal, expiry, sleep-length monotonic jumps, helper restart recovery, shutdown, missing interfaces, silent write failure, failed journal writes, failed restoration, failed marker cleanup, mode precedence, watched-app matching, the interface ioctl request encoding (with a read-only flag query), removal/disable behavior, preset matching, preservation of existing app choices, and persistence round trips.

## Manual release checklist

Perform network-control tests on a Mac where temporarily disabling AWDL will not interrupt an AirDrop transfer or a Continuity workflow.

- [ ] Inspect overview, applications, activity, settings, and menu bar at the minimum window size.
- [ ] Test dark/light appearance, Reduce Transparency, VoiceOver labels, and keyboard focus.
- [ ] Install a notarized app in Applications; enable its helper and approve it in System Settings.
- [ ] Verify no repeated password prompts, missing helper errors, or signature failures.
- [ ] Select Always on; confirm `IFF_UP` disappears from `/sbin/ifconfig awdl0`.
- [ ] Verify active / Auto waiting / paused have distinct text, icons, and color; changing the mode alone must not claim successful boost.
- [ ] Open the ? explanation panel, inspect packet timing illustration, scroll to the trade-off and source links, and dismiss using Escape/Return.
- [ ] With boost active, run `sudo ifconfig awdl0 up` and confirm `IFF_UP` is gone again immediately. `log stream --predicate 'subsystem == "io.github.burakgon.StopStutter.Helper"'` shows each correction, and the overview counts blocked AWDL wake-ups.
- [ ] With boost active and AWDL already down, confirm `log stream --predicate 'process == "airportd" AND eventMessage CONTAINS "awdl0"'` shows no flag-change event every second.
- [ ] Select Off; verify `IFF_UP` returns and a restore event/banner appears.
- [ ] Choose Auto; launch a selected client and verify AWDL goes down.
- [ ] Keep two selected clients running; quit one and confirm boost remains. Quit the other and confirm restoration.
- [ ] Add a custom app through the native picker; disable/remove its rule while it runs and verify reconciliation.
- [ ] Leave a client window closed but its process running; verify boost correctly remains active.
- [ ] Quit Stop Stutter during boost; verify AWDL returns.
- [ ] Force quit Stop Stutter; verify disconnect/expiry recovery. Restart it and confirm rules resume.
- [ ] Freeze the app during boost; verify lease expiry and recovery. Resume and confirm control resumes.
- [ ] Kill the helper during boost on a test system; verify restart and recovery marker handling.
- [ ] Test sleep/wake, switching users, notification denial, and helper permission revocation.
- [ ] Remove the helper in Settings; verify launchd registration is removed and AWDL is up.
- [ ] With boost off, replace the installed app with a newer build; confirm the helper restarts on the new executable without re-approval (`launchctl print system/io.github.burakgon.StopStutter.Helper` shows a new PID).
- [ ] Check the ZIP on a second Mac. Test Intel and macOS 14/15 separately from Apple Silicon and 26+.

Record what actually ran in the release notes. Do not infer a streaming improvement from network-interface state alone; compare the same stream with boost off/on to measure that.
