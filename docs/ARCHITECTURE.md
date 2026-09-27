# Architecture and security

## Targets

- `StopStutter`: SwiftUI/AppKit app, user preferences, NSWorkspace app monitoring, notifications, SMAppService registration, and the XPC client.
- `StopStutterHelper`: privileged launch daemon, interface-event monitor, serialized safety timer, per-connection leases, signal handling, update detection, and recovery journal.
- `StopStutterCore`: policy, the testable enforcement engine, fixed interface driver, XPC protocol, and peer trust requirements.

No network requests, telemetry, external packages, shell interpreter, sudoers changes, private APIs, or kernel extensions are used. GitHub links open in the browser only when selected. The public download is distributed outside the Mac App Store; the app is not sandboxed because its purpose requires a privileged daemon.

## Trust boundary

The app and helper are independently signed, with hardened runtime enabled. Before accepting a connection the helper's `NSXPCListener` checks the exact app identifier and the Apple signing team read from the helper's own signature. The app independently checks the helper's exact identifier and same signing team. Apple validates the live XPC peer rather than the app manually looking up a mutable PID. Ad-hoc binaries have no accepted team identifier and fail closed.

The exported protocol has one operation: renew or release the **calling connection's** lease and return status. The caller cannot choose another session's identifier, target a different interface, pass a command, or supply a path. App-name preferences and bundle paths never cross this boundary. Local users with a correctly signed copy can request AWDL control; an additional lease from another user/session prevents early restoration. Do not consider possession of the developer's signing key an untrusted scenario.

Requests, interface events, the one-second safety timer, and disconnect callbacks are serialized on one queue. The helper runs no external programs: it reads and changes only `awdl0`’s administrative `IFF_UP` flag with the `SIOCGIFFLAGS`/`SIOCSIFFLAGS` ioctls that `ifconfig awdl0 up|down` uses. Verification reads `IFF_UP`, not `status: active` (which describes different link behavior). The helper writes only when the flag is wrong: every write makes the kernel broadcast a flag change to the Wi-Fi daemons, even when nothing changed.

macOS may revive AWDL at any moment. A routing socket delivers the kernel’s `RTM_IFINFO` message for every interface’s `IFF_UP` transition, so the helper re-checks `awdl0` and corrects a revival within milliseconds, before AWDL resumes its channel schedule. Corrections are spaced at least 20 ms apart, so a daemon that fights back cannot cause a busy loop. Heartbeats also enforce before replying, and the one-second timer catches anything the event path misses. Session starts and ends, revivals, expired leases, and errors are written to the unified log under the helper’s subsystem.

## Ownership and crash recovery

Before the first down command, the helper creates and syncs a marker in a root-owned `0700` directory under `/private/var/db`. The leaf directory must be a real directory owned by root, with no group/other access; an existing marker must be a root-owned regular file with restrictive permissions. Marker creation uses `O_EXCL | O_NOFOLLOW`. No user-provided recovery path is accepted.

The marker means “this helper owes an AWDL up.” Recovery clears it only after `IFF_UP` is verified, writing it first if needed. Recovery failures retain ownership and retry. A helper restart sees the marker and attempts restoration before handling new connections. A SIGTERM handler attempts restoration on orderly service removal; launchd restarts nonzero exits. A forced kill is recovered by the next launch, subject to normal OS scheduling and service approval.

The app renews its connection's ten-second lease every two seconds. While Boost is requested, it holds a user-initiated activity so App Nap cannot delay renewals, and its timer runs in common run loop modes. The helper's timer expires leases using continuous monotonic time, which advances over sleep and ignores wall-clock changes. Only the last lease ending triggers restoration. Control returns to AWDL up after Boost, regardless of its state before Boost. With no lease or recovery marker, the daemon never changes the interface.

The UI treats a Boost as active only after a successful response that says the helper owns control, a lease exists, the interface is down, and no error is present. RPC timeout/error paths do not claim active Boost. RPC completion is guarded against duplicate replies and timeouts. A timed-out request keeps the connection, and with it the lease, because invalidating would release the lease at once; only a failed connection is replaced. A heartbeat failure lets the lease expire; the client retries on its next poll. While Boost is still requested, a reply showing AWDL up is treated as a revival being corrected, not as the end of the session.

## Updates

The helper records its executable’s identity at launch. A process whose executable was replaced fails every client’s code-signature check (`errSecCSNoSuchCode`), so it can no longer serve anyone. Once the replacement has stayed unchanged for two checks, the helper restores AWDL, exits with a temporary-failure status, and launchd starts the new build. No re-approval is needed while the launchd plist is unchanged.

A 0.1.0 helper predates this and keeps running until the Mac restarts or the helper is removed and enabled again. The app explains this when the signature check fails, and removal no longer requires reaching the helper: an unreachable helper restores AWDL itself when macOS stops it. A failed removal restores the previous Boost mode.

## Limits

- Event delivery and scheduling on a general-purpose OS are not hard real-time guarantees. AWDL is active for the short time between macOS reviving it and the helper’s correction.
- A missing interface, helper that cannot start, OS networking error, power loss, or forced removal can prevent immediate restoration. The persistent marker and retries reduce this risk; the manual recovery command remains documented.
- The app observes application lifetime. It cannot tell whether a client is actively streaming.
- The enforcement mechanism is a workaround for AWDL interference, not a general network optimizer or streaming performance guarantee.
- Apple Silicon runtime behavior is tested on the development Mac. Intel and older supported macOS versions require their own runtime coverage; successful universal compilation is not equivalent to testing them on hardware.
