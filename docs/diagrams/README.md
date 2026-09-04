# README infographics

These original SVGs are included under the repository’s [MIT license](../../LICENSE). They use embedded shapes and text, without external fonts, images, scripts, or rendering dependencies. The dark background is part of each image, so the diagrams retain their contrast in either GitHub theme. Each SVG has a title and a text description; the main README also supplies alternative text.

| Diagram | What it explains |
| --- | --- |
| [AWDL on vs. off](awdl-on-vs-off.svg) | Active AWDL can share the Mac’s Wi-Fi radio with infrastructure traffic. Disabling AWDL removes that source of contention. |
| [Packet timing](packet-timing.svg) | Equal packet counts can hide different arrival timing. A delay followed by a burst can matter to a real-time stream. |
| [Boost lifecycle](boost-lifecycle.svg) | App launch and quit, repeated interface commands, authenticated XPC, and lease renewal/recovery. |

## Evidence and scope

- [Apple Developer Technical Support: Peer-to-Peer Wi-Fi](https://developer.apple.com/forums/thread/751839) explains that peer-to-peer Wi-Fi can also introduce latency into infrastructure traffic.
- [Stute, Kreitschmann, and Hollick: One Billion Apples’ Secret Sauce](https://arxiv.org/abs/1808.03156) describes AWDL’s synchronized availability windows, channel sequence, and coexistence with infrastructure Wi-Fi. This is protocol research on older software and hardware; the illustrations deliberately do not prescribe its historical channel numbers or timing constants to current Macs.
- [The enforcement engine](../../Sources/StopStutterCore/EnforcementEngine.swift), [service constants](../../Sources/StopStutterCore/Models.swift), and [architecture notes](../ARCHITECTURE.md) describe Stop Stutter’s actual control and recovery behavior.

The radio-time segments and packet-arrival positions are **conceptual illustrations**, not captured traces, proportional airtime allocations, benchmarks, or guaranteed before-and-after results. AWDL being enabled does not imply continuous activity. Other Wi-Fi traffic and other causes of jitter still exist with AWDL disabled. A packet does not represent a complete video frame.

The one-second markers in the lifecycle diagram represent the helper’s intended command cadence. They are unrelated to AWDL’s own protocol schedule, are not real-time guarantees, and do not imply macOS cannot reactivate AWDL between commands. Restoration is attempted, verified, and retried on failure; it is not guaranteed if the OS or helper is unavailable. See the [validation record](../VALIDATION.md) for tested behavior.

## Editing

Edit [`scripts/generate-diagrams.py`](../../scripts/generate-diagrams.py), then regenerate from the repository root:

```sh
python3 scripts/generate-diagrams.py
```

The generator uses only Python’s standard library. Commit both the source and generated SVGs. Preview them at a typical README width as well as full size, check text bounds, and keep the visible “conceptual / not a benchmark” captions when changing the illustrations. Preserve the user-provided app screenshot separately; these diagrams do not replace it.
