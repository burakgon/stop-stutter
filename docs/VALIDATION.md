# Validation record

## 0.1.1

Same development host: Apple Silicon Mac, macOS 27.0, Xcode 27.0. Checked during a real Punktfunk session, first with the approved 0.1.0 helper, then with the 0.1.1 helper.

### Diagnosis on 0.1.0

- `airportd` logged `KEV_DL_SIFFLAGS` for `awdl0` every second while AWDL was already down. Each unconditional `ifconfig awdl0 down` broadcast a flag change.
- During the session `wifip2pd` repeatedly restored AWDL for Continuity and widget clients (“restored awdl0 link state to Link Up”). AWDL then stayed up until the next one-second tick. The longer logged episodes lasted 455, 485, 706, 764, and 826 ms, long enough for AWDL to start its channel schedule.
- Heartbeats that landed in those windows produced a “Boost is off” and a “Boost is on” notification two seconds apart.
- A routing-socket probe received `RTM_IFINFO` at each `awdl0` IFF_UP transition, about 22 ms before the driver’s `KEV_DL_LINK_ON` event.

### Checks completed

- 34 automated tests, including writing only on the wrong state, correction on events and heartbeats, bounded verification retries, revival counting, and expired-lease accounting.
- GitHub Actions passed the tests and the universal build for both 0.1.1 commits.
- A Developer ID–signed universal build replaced 0.1.0 in Applications. The 0.1.0 helper kept running from its deleted executable, so the new app’s replies failed the helper’s code-signature check (`errSecCSNoSuchCode`, -67065) and AWDL flapped as each rejected request took and dropped a lease. A root `launchctl kickstart -k` loaded the 0.1.1 helper. This led to the update-recovery changes: the helper restarts itself once replaced, and Remove Helper no longer needs to reach it.
- The 0.1.1 helper logged revision 2, took the Punktfunk lease, and held `IFF_UP` off. `launchctl` reported zero forks, and `airportd` logged no further `awdl0` flag changes while AWDL stayed down. Over the next 16 minutes the helper logged no revivals, errors, or expired leases, and AWDL stayed down throughout.

### Not yet covered

- A macOS revival corrected by the 0.1.1 helper on this Mac. None occurred in those 16 minutes, although 0.1.0 had logged several in the preceding hour; the routing-socket signal the correction relies on was observed on 0.1.0.
- Helper self-restart after an update from 0.1.1 or later, and removal of an unreachable 0.1.0 helper through Remove Helper.
- No stream-quality benchmark was run. These checks show interface behavior, not frame pacing.

## 0.1.0

Development host: Apple Silicon Mac, macOS 27.0 developer beta, Xcode 27.0. Deployment target: macOS 14.0. Built and inspected both arm64 and x86_64 slices. With Xcode 27, the linked SDK version is explicitly stamped by the build script to enable the system's modern Liquid Glass behavior.

GitHub Actions also passed all 28 tests and the universal build on macOS 26 with Xcode 26.5. Both slices report a macOS 14.0 minimum and the correct 26.5 linked SDK.

### Checks completed

- 28 automated tests for control policy, lease ownership, error recovery, persistence, and truthful UI state classification.
- Streaming presets: verified Parsec’s identifier from its official macOS package, Steam Link’s from Apple’s app metadata, and GeForce NOW’s from its official macOS disk image. Matching and preservation of disabled/custom rules have automated coverage.
- Added GeForce NOW, Parsec, and Steam Link through the native suggested-app controls; all five selected rules and their official icons are visible together on the overview. The latest icon bundle passed signing, notarization, and CI again.
- Native application picker: selected TextEdit, verified its persisted rule, then removed the temporary rule.
- Native AWDL explanation sheet: opened from the ? button, inspected both ends of its scrollable content, verified source links are present, and dismissed with Escape.
- Revised UI states: observed and captured active green Boost ON, blue Auto waiting / Boost OFF, and neutral paused Boost OFF against the live helper.
- Approved SMAppService helper installed and running under launchd.
- Actual interface checks using `/sbin/ifconfig awdl0`: the `UP` flag disappears during boost and returns after release.
- Manual boost through the UI: on and off matched the real interface state.
- Punktfunk launch triggered automatic boost; quitting it restored AWDL.
- A signed integration probe verified two independent leases, keeping AWDL down when only one ends, restoration when the last ends, immediate disconnect recovery, and recovery after a heartbeat stops.
- A probe with the same bundle identifier but only an ad-hoc signature was rejected by the helper.
- In-app helper removal completed; launchd no longer listed the service and AWDL remained up.
- Hardened runtime signing, Apple notarization, stapled ticket validation, and Gatekeeper assessment completed for the release bundle.

### Remaining hardware and scenario coverage

These checks establish control behavior; they are **not a measurement of game-stream performance**. No before/after frame-loss, latency, or FPS benchmark was performed. Moonlight itself was not installed on the development Mac; automatic client behavior was verified with Punktfunk and bundle matching was tested separately.

Intel hardware and macOS 14, 15, and 26 runtime testing are still needed. Real sleep/wake, fast user switching, power loss, forced helper termination, and a second-Mac fresh install have not been exercised end to end. Their core recovery policies have automated coverage where applicable; compilation is not a substitute for those system tests.
