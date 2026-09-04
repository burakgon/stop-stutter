# Architecture and security

## Targets

- `StopStutter`: SwiftUI/AppKit app, user preferences, NSWorkspace app monitoring, notifications, SMAppService registration, and the XPC client.
- `StopStutterHelper`: privileged launch daemon, serialized enforcement timer, per-connection leases, signal handling, and recovery journal.
- `StopStutterCore`: policy, the testable enforcement engine, fixed interface driver, XPC protocol, and peer trust requirements.

No network requests, telemetry, external packages, shell interpreter, sudoers changes, private APIs, or kernel extensions are used. GitHub links open in the browser only when selected. The public download is distributed outside the Mac App Store; the app is not sandboxed because its purpose requires a privileged daemon.

## Trust boundary

The app and helper are independently signed, with hardened runtime enabled. Before accepting a connection the helper's `NSXPCListener` checks the exact app identifier and the Apple signing team read from the helper's own signature. The app independently checks the helper's exact identifier and same signing team. Apple validates the live XPC peer rather than the app manually looking up a mutable PID. Ad-hoc binaries have no accepted team identifier and fail closed.

The exported protocol has one operation: renew or release the **calling connection's** lease and return status. The caller cannot choose another session's identifier, target a different interface, pass a command, or supply a path. App-name preferences and bundle paths never cross this boundary. Local users with a correctly signed copy can request AWDL control; an additional lease from another user/session prevents early restoration. Do not consider possession of the developer's signing key an untrusted scenario.

Each request is serialized with the one-second timer and disconnect callbacks. The helper executes only `/sbin/ifconfig`, with exactly `awdl0` plus `up` or `down`, a fixed environment, no stdin, and a bounded runtime. Interface verification reads `IFF_UP` via `getifaddrs`, not `status: active` (which describes different link behavior). This verifies administrative state at that instant; macOS may revive AWDL immediately afterward, which is why the timer repeats the command.

## Ownership and crash recovery

Before the first down command, the helper creates and syncs a marker in a root-owned `0700` directory under `/private/var/db`. The leaf directory must be a real directory owned by root, with no group/other access; an existing marker must be a root-owned regular file with restrictive permissions. Marker creation uses `O_EXCL | O_NOFOLLOW`. No user-provided recovery path is accepted.

The marker means “this helper owes an AWDL up.” Recovery clears it only after `ifconfig up` succeeds and `IFF_UP` is verified. Recovery failures retain ownership and retry. A helper restart sees the marker and attempts restoration before handling new connections. A SIGTERM handler attempts restoration on orderly service removal; launchd restarts nonzero exits. A forced kill is recovered by the next launch, subject to normal OS scheduling and service approval.

The app renews its connection's six-second lease every two seconds. The helper's timer expires leases using continuous monotonic time, which advances over sleep and ignores wall-clock changes. Only the last lease ending triggers restoration. Control returns to AWDL up after protection, regardless of its state before protection. With no lease or recovery marker, the daemon never changes the interface.

The UI treats a session as protected only after a successful response that says the helper owns control, a lease exists, the interface is down, and no error is present. RPC timeout/error paths do not claim protection. RPC completion is guarded against duplicate replies and timeouts. A heartbeat failure lets the lease expire; the client retries on its next poll.

## Limits

- A timer on a general-purpose OS is not a hard real-time guarantee. Tick scheduling and command completion can be delayed.
- A missing interface, helper that cannot start, OS networking error, power loss, or forced removal can prevent immediate restoration. The persistent marker and retries reduce this risk; the manual recovery command remains documented.
- The app observes application lifetime. It cannot tell whether a client is actively streaming.
- The enforcement mechanism is a workaround for AWDL interference, not a general network optimizer or streaming performance guarantee.
- Apple Silicon runtime behavior is tested on the development Mac. Intel and older supported macOS versions require their own runtime coverage; successful universal compilation is not equivalent to testing them on hardware.
