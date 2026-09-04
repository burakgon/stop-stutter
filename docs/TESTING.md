# Test coverage

## Automated

`swift test` uses an in-memory interface driver and recovery journal. It never changes networking, invokes sudo, or registers a daemon.

The suite covers repeated down commands, OS reactivation, multiple independent leases, immediate disconnect recovery, heartbeat renewal, expiry, sleep-length monotonic jumps, helper restart recovery, shutdown, missing interfaces, silent write failure, failed journal writes, failed restoration, failed marker cleanup, mode precedence, watched-app matching, removal/disable behavior, and persistence round trips.

## Manual release checklist

Perform network-control tests on a Mac where temporarily disabling AWDL will not interrupt an AirDrop transfer or a Continuity workflow.

- [ ] Inspect overview, applications, activity, settings, and menu bar at the minimum window size.
- [ ] Test dark/light appearance, Reduce Transparency, VoiceOver labels, and keyboard focus.
- [ ] Install a notarized app in Applications; enable its helper and approve it in System Settings.
- [ ] Verify no repeated password prompts, missing helper errors, or signature failures.
- [ ] Select Always on; confirm `IFF_UP` disappears from `/sbin/ifconfig awdl0`.
- [ ] Verify active / Auto waiting / paused have distinct text, icons, and color; changing the mode alone must not claim successful protection.
- [ ] Open the ? explanation panel, inspect packet timing illustration, scroll to the trade-off and source links, and dismiss using Escape/Return.
- [ ] Observe the one-second loop over several ticks; optionally bring AWDL up and confirm it is disabled again.
- [ ] Select Off; verify `IFF_UP` returns and a restore event/banner appears.
- [ ] Choose Auto; launch a selected client and verify AWDL goes down.
- [ ] Keep two selected clients running; quit one and confirm protection remains. Quit the other and confirm restoration.
- [ ] Add a custom app through the native picker; disable/remove its rule while it runs and verify reconciliation.
- [ ] Leave a client window closed but its process running; verify protection correctly remains active.
- [ ] Quit Stop Stutter during protection; verify AWDL returns.
- [ ] Force quit Stop Stutter; verify disconnect/expiry recovery. Restart it and confirm rules resume.
- [ ] Freeze the app during protection; verify lease expiry and recovery. Resume and confirm control resumes.
- [ ] Kill the helper during protection on a test system; verify restart and recovery marker handling.
- [ ] Test sleep/wake, switching users, notification denial, and helper permission revocation.
- [ ] Remove the helper in Settings; verify launchd registration is removed and AWDL is up.
- [ ] Check the ZIP on a second Mac. Test Intel and macOS 14/15 separately from Apple Silicon and 26+.

Record what actually ran in the release notes. Do not infer a streaming improvement from network-interface state alone; compare the same stream with protection off/on to measure that.
