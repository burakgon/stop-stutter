# Changelog

## 0.1.1 — 2026-09-27

Steadier Boost sessions.

- The helper now reacts to the kernel's interface notifications and turns AWDL off again within milliseconds when macOS revives it. Before, AWDL could stay active for up to a second, long enough to stutter a stream.
- The helper no longer rewrites AWDL every second while it is already off. Each write made the kernel broadcast a flag change that woke the Wi-Fi daemons.
- Interface changes use the kernel's flag ioctls directly instead of launching `/sbin/ifconfig` for each command.
- A heartbeat that catches AWDL mid-revival no longer ends the session with "Boost is off" and "Boost is on" notifications. The overview counts blocked AWDL wake-ups instead.
- App Nap can no longer delay lease renewal during a session. Renewal continues while menus are open, and a slow reply keeps the lease instead of releasing it. Leases now last ten seconds.
- After future updates, the helper restarts itself on the new build within seconds, without a password or re-approval.
- Updating from 0.1.0 needs one step: restart the Mac, or use Remove Helper and then Enable Helper. Remove Helper now works even when the old helper can no longer be reached, and a failed removal keeps your Boost mode.
- Stop Stutter runs as a menu bar app without a Dock icon (#2).

## 0.1.0 — 2026-09-04

First public preview.

- Native SwiftUI app with Liquid Glass controls on macOS 26+ and a menu bar companion.
- Automatic AWDL suppression for user-selected apps, with presets for Moonlight, GeForce NOW, Punktfunk, Parsec, and Steam Link.
- Auto / Always on / Off Boost modes, a benefit-led main screen, and distinct active, waiting, paused, setup, transition, and error states.
- All selected apps appear on the overview, with official client icons and individual Auto toggles.
- Optional suggested apps preserve existing user choices.
- Illustrated in-app explanation of AWDL-related latency, one-second enforcement, and the Apple sharing trade-off.
- Privileged helper with one-second enforcement, authenticated XPC, expiring leases, and durable recovery.
- Quiet notifications, a session activity feed, optional launch at login, and in-app helper removal.
- MIT-licensed source, automated policy/recovery tests, and reproducible signing/notarization scripts.

This release targets AWDL-related interference. Streaming performance varies; it is not a universal stutter fix.
