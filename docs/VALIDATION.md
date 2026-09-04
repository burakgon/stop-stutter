# 0.1.0 validation record

Development host: Apple Silicon Mac, macOS 27.0 developer beta, Xcode 27.0. Deployment target: macOS 14.0. Built and inspected both arm64 and x86_64 slices. The linked SDK version is explicitly stamped by the build script to enable the system's modern Liquid Glass behavior.

## Checks completed

- 26 automated tests for control policy, lease ownership, error recovery, persistence, and truthful UI state classification.
- Native application picker: selected TextEdit, verified its persisted rule, then removed the temporary rule.
- Native AWDL explanation sheet: opened from the ? button, inspected both ends of its scrollable content, verified source links are present, and dismissed with Escape.
- Revised UI states: observed and captured active green Protection ON / AWDL OFF, blue Auto waiting / Protection OFF, and neutral paused Protection OFF / AWDL ON against the live helper.
- Approved SMAppService helper installed and running under launchd.
- Actual interface checks using `/sbin/ifconfig awdl0`: the `UP` flag disappears during protection and returns after release.
- Manual protection through the UI: on and off matched the real interface state.
- Punktfunk launch triggered automatic protection; quitting it restored AWDL.
- A signed integration probe verified two independent leases, keeping AWDL down when only one ends, restoration when the last ends, immediate disconnect recovery, and recovery after a heartbeat stops.
- A probe with the same bundle identifier but only an ad-hoc signature was rejected by the helper.
- In-app helper removal completed; launchd no longer listed the service and AWDL remained up.
- Hardened runtime signing, Apple notarization, stapled ticket validation, and Gatekeeper assessment completed for the release bundle.

## Remaining hardware and scenario coverage

These checks establish control behavior; they are **not a measurement of game-stream performance**. No before/after frame-loss, latency, or FPS benchmark was performed. Moonlight itself was not installed on the development Mac; automatic client behavior was verified with Punktfunk and bundle matching was tested separately.

Intel hardware and macOS 14, 15, and 26 runtime testing are still needed. Real sleep/wake, fast user switching, power loss, forced helper termination, and a second-Mac fresh install have not been exercised end to end. Their core recovery policies have automated coverage where applicable; compilation is not a substitute for those system tests.
