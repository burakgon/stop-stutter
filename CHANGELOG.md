# Changelog

## 0.1.0 — 2026-09-04

First public preview.

- Native SwiftUI app with Liquid Glass controls on macOS 26+ and a menu bar companion.
- Automatic AWDL suppression for user-selected apps, including Moonlight and Punktfunk suggestions.
- Manual Auto / Always on / Off protection modes, explicit protection and AWDL status, and distinct active, waiting, paused, setup, transition, and error states.
- Illustrated in-app explanation of AWDL-related latency, one-second enforcement, and the Apple sharing trade-off.
- Privileged helper with one-second enforcement, authenticated XPC, expiring leases, and durable recovery.
- Quiet notifications, a session activity feed, optional launch at login, and in-app helper removal.
- MIT-licensed source, automated policy/recovery tests, and reproducible signing/notarization scripts.

This release targets AWDL-related interference. Streaming performance varies; it is not a universal stutter fix.
