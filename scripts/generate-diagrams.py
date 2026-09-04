#!/usr/bin/env python3
"""Generate the README's original, self-contained SVG diagrams (stdlib only).

Run from any directory: python3 scripts/generate-diagrams.py
These are conceptual illustrations, not captured performance measurements.
"""

from html import escape
from pathlib import Path

OUT = Path(__file__).resolve().parents[1] / "docs" / "diagrams"
BG, PANEL, BORDER = "#081417", "#101f24", "#294047"
WHITE, MUTED = "#effaf8", "#a8bec3"
MINT, BLUE, AMBER = "#54e5be", "#81baff", "#ffc47c"
FONT = "-apple-system, BlinkMacSystemFont, 'Segoe UI', Helvetica, Arial, sans-serif"
MONO = "ui-monospace, SFMono-Regular, Menlo, Consolas, monospace"


class Diagram:
    def __init__(self, height, title, description):
        self.parts = [
            f'<svg xmlns="http://www.w3.org/2000/svg" width="1280" height="{height}" '
            f'viewBox="0 0 1280 {height}" role="img" aria-labelledby="title desc">',
            f'<title id="title">{escape(title)}</title>',
            f'<desc id="desc">{escape(description)}</desc>',
            f'<rect width="1280" height="{height}" fill="{BG}"/>',
        ]

    def rect(self, x, y, w, h, fill=PANEL, stroke="none", radius=16):
        self.parts.append(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" '
                          f'rx="{radius}" fill="{fill}" stroke="{stroke}"/>')

    def text(self, x, y, value, size=24, color=WHITE, weight=400, anchor="start", mono=False):
        font = MONO if mono else FONT
        self.parts.append(f'<text x="{x}" y="{y}" fill="{color}" font-family="{font}" '
                          f'font-size="{size}" font-weight="{weight}" text-anchor="{anchor}">'
                          f'{escape(value)}</text>')

    def line(self, x1, y1, x2, y2, color=BORDER, width=2, dashed=False):
        dash = ' stroke-dasharray="7 8"' if dashed else ""
        self.parts.append(f'<line x1="{x1}" y1="{y1}" x2="{x2}" y2="{y2}" '
                          f'stroke="{color}" stroke-width="{width}" stroke-linecap="round"{dash}/>')

    def circle(self, x, y, r, fill, stroke="none", width=2):
        self.parts.append(f'<circle cx="{x}" cy="{y}" r="{r}" fill="{fill}" '
                          f'stroke="{stroke}" stroke-width="{width}"/>')

    def path(self, path, color, width=3, fill="none"):
        self.parts.append(f'<path d="{path}" fill="{fill}" stroke="{color}" '
                          f'stroke-width="{width}" stroke-linecap="round" stroke-linejoin="round"/>')

    def arrow(self, x1, y, x2, color=BLUE, dashed=False):
        self.line(x1, y, x2, y, color, 3, dashed)
        self.path(f'M {x2-8} {y-6} L {x2} {y} L {x2-8} {y+6}', color)

    def heading(self, number, label, title, subtitle):
        self.text(40, 43, f"{number}  /  {label}", 18, MINT, 650)
        self.text(1240, 43, "STOP STUTTER", 18, MUTED, 600, "end")
        self.text(40, 105, title, 46, WHITE, 700)
        self.text(40, 146, subtitle, 23, MUTED)

    def router(self, x, y, color=BLUE):
        self.rect(x-27, y-7, 54, 26, "none", color, 6)
        self.line(x-18, y-7, x-18, y-23, color, 3)
        self.line(x+18, y-7, x+18, y-23, color, 3)
        for offset in [-12, 0, 12]:
            self.circle(x+offset, y+6, 2, color)

    def laptop(self, x, y, color=WHITE):
        self.rect(x-37, y-31, 74, 47, "none", color, 5)
        self.path(f'M {x-45} {y+24} H {x+45} L {x+37} {y+16} H {x-37} Z', color, 2)
        self.path(f'M {x-17} {y-13} Q {x} {y-29} {x+17} {y-13}', MINT, 3)
        self.path(f'M {x-10} {y-5} Q {x} {y-15} {x+10} {y-5}', MINT, 3)
        self.circle(x, y+3, 2.5, MINT)

    def peers(self, x, y, color=AMBER):
        self.rect(x-24, y-24, 31, 48, "none", color, 6)
        self.rect(x+1, y-14, 25, 38, PANEL, color, 5)
        self.line(x-15, y+17, x-7, y+17, color, 2)
        self.circle(x+13, y+17, 1.5, color)

    def save(self, name):
        OUT.mkdir(parents=True, exist_ok=True)
        (OUT / name).write_text("\n".join(self.parts + ["</svg>"]) + "\n")


def radio_comparison():
    d = Diagram(790, "AWDL on versus AWDL off with Boost", "Conceptual comparison of one Mac Wi-Fi radio. "
                "With Boost off, active AWDL can share radio time with router traffic, including channel switches. "
                "With Boost on, Stop Stutter repeatedly disables awdl0, removing this source of contention. "
                "AWDL being up does not mean continuous transmission. This is not a performance measurement.")
    d.heading("01", "THE RADIO", "Same Wi-Fi. Less contention.",
              "Boost targets a source of stutter that a faster internet plan may not fix.")
    for x, boosted in [(40, False), (656, True)]:
        color = MINT if boosted else AMBER
        d.rect(x, 181, 584, 462, PANEL, BORDER, 24)
        d.circle(x+34, 219, 6, color)
        d.text(x+53, 228, "BOOST ON" if boosted else "BOOST OFF", 25, color, 700)
        d.text(x+28, 269, "AWDL OFF  /  awdl0 DOWN" if boosted else "AWDL ON  /  awdl0 UP", 21, MUTED, mono=True)
        d.line(x+28, 291, x+556, 291)
        router, mac, peer = x+80, x+292, x+504
        d.router(router, 359)
        d.laptop(mac, 359)
        d.peers(peer, 359, MUTED if boosted else AMBER)
        d.arrow(router+45, 353, mac-59, BLUE)
        d.arrow(mac+59, 353, peer-42, BORDER if boosted else AMBER, boosted)
        if boosted:
            d.circle(x+398, 353, 15, PANEL, MUTED)
            d.line(x+389, 344, x+407, 362, MUTED, 2)
        d.text(router, 414, "Router", 22, BLUE, 600, "middle")
        d.text(mac, 414, "One Mac radio", 22, WHITE, 600, "middle")
        d.text(peer, 414, "Nearby peers", 21, MUTED if boosted else AMBER, 500, "middle")
        d.text(x+28, 473, "ILLUSTRATIVE RADIO TIME", 17, MUTED, 600)
        if boosted:
            d.rect(x+28, 493, 528, 43, "#173651", radius=8)
            d.text(x+292, 522, "Router traffic • AWDL held off", 21, BLUE, 600, "middle")
        else:
            segments = [(0, 154, BLUE, "Router"), (160, 92, AMBER, "AWDL"),
                        (258, 104, BLUE, "Router"), (368, 92, AMBER, "AWDL"), (466, 62, BLUE, "…")]
            for offset, width, fill, label in segments:
                d.rect(x+28+offset, 493, width, 43, "#173651" if fill == BLUE else "#423325", radius=8)
                d.text(x+28+offset+width/2, 522, label, 20, fill, 600, "middle")
        d.text(x+28, 582, "More radio time for your stream." if boosted else "AWDL activity can make packets wait.", 24, WHITE, 600)
        d.text(x+28, 615, "Other sources of jitter can still remain." if boosted else "Especially when it uses another channel.", 21, MUTED)
    d.text(40, 693, "When AWDL takes the radio off the router’s channel, stream packets can be delayed.", 24, WHITE, 500)
    d.text(40, 735, "Conceptual channel sharing, not a benchmark. AWDL being UP does not mean continuous activity.", 21, MUTED)
    d.text(40, 766, "Actual behavior varies with the Mac, macOS version, nearby devices, and Wi-Fi environment.", 21, MUTED)
    d.save("awdl-on-vs-off.svg")


def packet_timing():
    d = Diagram(748, "Why packet timing matters to game streaming", "Two illustrative arrival timelines carry the same eight "
                "packets. One has a gap followed by a burst; the other is evenly spaced. Average throughput alone does not "
                "describe jitter. Packets delayed by AWDL contention can miss a frame deadline. Disabling AWDL can remove "
                "that delay source, but does not guarantee even delivery. The timelines are not measurements or guaranteed before and after results.")
    d.heading("02", "PACKET TIMING", "Fast internet can still feel slow.",
              "A stream needs data on time. Average bandwidth does not show every interruption.")
    d.rect(40, 183, 1200, 347, PANEL, BORDER, 24)
    d.text(72, 225, "SAME PACKET COUNT. DIFFERENT ARRIVAL TIMING.", 19, MUTED, 650)
    d.text(1197, 225, "time →", 20, MUTED, anchor="end")
    start, end = 341, 1197
    for y, label, detail, color in [(308, "Uneven delivery", "Gap, then a burst", AMBER),
                                    (452, "Steadier delivery", "Less arrival-time variation", MINT)]:
        d.text(72, y-7, label, 25, color, 650)
        d.text(72, y+28, detail, 20, MUTED)
        d.line(start, y+1, end, y+1, BORDER, 2)
    positions = [357, 459, 790, 835, 880, 969, 1071, 1173]
    d.rect(493, 264, 273, 88, "#322a22", radius=10)
    d.text(629, 298, "Packets wait", 23, AMBER, 600, "middle")
    d.text(629, 328, "e.g. radio unavailable", 19, MUTED, anchor="middle")
    for i, x in enumerate(positions):
        d.rect(x-16, 282, 32, 51, "#59412a", AMBER, 7)
        d.text(x, 315, str(i+1), 20, AMBER, 650, "middle", mono=True)
    d.text(835, 374, "Delayed packets arrive together", 20, AMBER, anchor="middle")
    for i in range(8):
        x = 357 + i * (816 / 7)
        d.rect(round(x-16, 1), 426, 32, 51, "#173e34", MINT, 7)
        d.text(round(x, 1), 459, str(i+1), 20, MINT, 650, "middle", mono=True)
    d.text(1197, 510, "8 packets in each row • schematic spacing", 18, MUTED, anchor="end")
    for x, step, title, body in [(40, "1", "Radio time is shared", "Active AWDL can delay Wi-Fi traffic."),
                                (452, "2", "A frame arrives late", "The stream may miss its deadline."),
                                (864, "3", "You feel the hitch", "Video, audio, or input can stutter.")]:
        d.circle(x+16, 579, 16, "#1d3738")
        d.text(x+16, 586, step, 18, MINT, 700, "middle")
        d.text(x+44, 587, title, 25, WHITE, 650)
        d.text(x, 623, body, 21, MUTED)
    d.line(40, 658, 1240, 658)
    d.text(40, 695, "Boost can help when AWDL causes that delay; it does not fix every cause of stutter.", 23, WHITE, 500)
    d.text(40, 728, "Conceptual timing only. These are not measured or guaranteed before-and-after results.", 21, MUTED)
    d.save("packet-timing.svg")


def session_lifecycle():
    d = Diagram(878, "Automatic Boost session and helper timing", "A selected app launches and Boost requests AWDL down "
                "immediately. A privileged helper repeats ifconfig awdl0 down once per second because macOS can reactivate "
                "AWDL. In Auto mode, the last selected app quitting releases Boost and the helper restores AWDL up. "
                "The normal-user app renews an authenticated XPC lease every two seconds. A lease expires after six seconds "
                "without renewal; the next helper tick attempts restoration when no leases remain.")
    d.heading("03", "AUTOMATION", "One session. No repeated commands.",
              "Choose your apps once. In Auto mode, Boost follows them from launch to quit.")
    steps = [(40, "01", "Open a selected app", "Request AWDL down immediately.", BLUE),
             (452, "02", "Keep playing", "Repeat down every second.", MINT),
             (864, "03", "Quit the last selected app", "Release Boost and restore AWDL.", BLUE)]
    for x, number, title, body, color in steps:
        d.rect(x, 183, 376, 157, PANEL, BORDER, 20)
        d.text(x+24, 218, number, 19, color, 700, mono=True)
        d.text(x+24, 263, title, 25 if number != "03" else 23, WHITE, 650)
        d.text(x+24, 304, body, 20, MUTED)
    d.arrow(425, 260, 443, MINT)
    d.arrow(837, 260, 855, MINT)
    d.rect(40, 365, 1200, 206, PANEL, BORDER, 24)
    d.text(68, 405, "WHY ONCE IS NOT ENOUGH", 18, MINT, 650)
    d.text(68, 447, "macOS can bring AWDL back up.", 28, WHITE, 650)
    d.text(68, 483, "The helper keeps reapplying down", 22, MUTED)
    d.text(68, 514, "for as long as Boost is requested.", 22, MUTED)
    d.line(559, 449, 1007, 449, MINT, 3)
    d.line(1007, 449, 1187, 449, BLUE, 3, True)
    for i, x in enumerate([571, 676, 781, 886, 991]):
        d.circle(x, 449, 8, MINT)
        d.text(x, 432, f"{i}s", 18, MUTED, anchor="middle", mono=True)
        d.text(x, 486, "DOWN", 18, MINT, 650, "middle", mono=True)
    d.circle(1165, 449, 8, BLUE)
    d.text(1165, 432, "last quit", 18, MUTED, anchor="middle")
    d.text(1165, 486, "UP", 18, BLUE, 650, "middle", mono=True)
    d.text(559, 543, "Repeating command cadence, not AWDL’s protocol schedule.", 20, MUTED)
    d.rect(40, 595, 1200, 169, PANEL, BORDER, 24)
    d.text(68, 632, "TWO CLOCKS, DIFFERENT JOBS", 18, MUTED, 650)
    d.text(68, 675, "SwiftUI app", 27, WHITE, 650)
    d.text(68, 712, "Normal user • renews lease every 2s", 21, MUTED)
    d.arrow(469, 672, 774, MINT)
    d.text(621, 659, "Authenticated XPC", 21, MINT, 550, "middle")
    d.text(621, 712, "Boolean Boost request", 19, MUTED, anchor="middle")
    d.text(810, 675, "macOS-managed helper", 27, WHITE, 650)
    d.text(810, 712, "Privileged • applies down every 1s", 21, MUTED)
    d.text(40, 810, "App stops responding? Its lease expires after 6s without renewal; the next tick attempts restore.", 23, WHITE, 500)
    d.text(40, 851, "Restore waits for all leases to end. Status is checked; failed restoration is retried. Timers are approximate.", 21, MUTED)
    d.save("boost-lifecycle.svg")


if __name__ == "__main__":
    radio_comparison()
    packet_timing()
    session_lifecycle()
