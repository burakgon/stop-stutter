import SwiftUI

struct AWDLExplanationView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.system(size: 24)).foregroundStyle(.mint)
                    .frame(width: 52, height: 52)
                    .modifier(GlassSurface(cornerRadius: 16))
                VStack(alignment: .leading, spacing: 5) {
                    Text("Fast Wi-Fi. Still stuttering?").font(.system(size: 23, weight: .bold, design: .rounded))
                    Text("Here’s where AWDL comes in.").font(.system(size: 13)).foregroundStyle(.secondary)
                }
                Spacer()
                Button { dismiss() } label: { Image(systemName: "xmark").font(.system(size: 13, weight: .semibold)) }
                    .buttonStyle(.bordered).clipShape(Circle()).keyboardShortcut(.cancelAction)
                    .accessibilityLabel("Close AWDL explanation")
            }.padding(26)
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 23) {
                    explanationStep("1", title: "One Wi-Fi radio, two jobs.",
                        text: "Your Mac uses AWDL (Apple Wireless Direct Link) to find and connect to nearby Apple devices for features like AirDrop. AWDL shares the Wi-Fi radio with your normal network and can switch it to a different channel.")
                    explanationStep("2", title: "A brief detour can interrupt a live stream.",
                        text: "While the radio serves nearby devices, packets from your router can be delayed. A speed test can still look great, but a live game stream may hitch, crackle, or feel less responsive. Consistent delivery matters as much as bandwidth.")

                    VStack(alignment: .leading, spacing: 15) {
                        packetRow(title: "AWDL active", caption: "Radio sharing can create gaps", interrupted: true, color: .orange)
                        packetRow(title: "AWDL held off", caption: "This source of interruption is removed", interrupted: false, color: .mint)
                        Text("Illustration of packet timing, not a live measurement or a performance guarantee.")
                            .font(.system(size: 10)).foregroundStyle(.secondary)
                    }
                    .padding(18)
                    .background(.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 16))
                    .accessibilityElement(children: .combine)

                    explanationStep("3", title: "Stop Stutter holds AWDL off while you play.",
                        text: "Protection disables only AWDL, leaving your normal Wi-Fi on. Because macOS can turn AWDL back on, the helper disables it again every second. In Auto mode, it restores AWDL after the last watched app quits.")

                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "airplay.audio").foregroundStyle(.orange).font(.system(size: 19))
                        VStack(alignment: .leading, spacing: 6) {
                            Text("The trade-off: Apple sharing takes a break.").font(.system(size: 13, weight: .semibold))
                            Text("AirDrop, peer-to-peer AirPlay, and some Continuity features may be unavailable while protection is on. Turn protection off when you need them.")
                                .font(.system(size: 12)).foregroundStyle(.secondary).lineSpacing(3)
                        }
                    }
                    .padding(16).background(.orange.opacity(0.06), in: RoundedRectangle(cornerRadius: 14))

                    Text("This helps when AWDL is the cause. It cannot fix a slow host, decoder problems, congestion, or every other source of stutter. Compare the same stream with protection on and off to see whether it helps your Mac.")
                        .font(.system(size: 12)).foregroundStyle(.secondary).lineSpacing(3)
                    HStack(spacing: 18) {
                        Link("Apple’s explanation ↗", destination: URL(string: "https://developer.apple.com/forums/thread/751839")!)
                        Link("Moonlight community reports ↗", destination: URL(string: "https://github.com/moonlight-stream/moonlight-qt/issues/753")!)
                    }.font(.system(size: 11))
                }.padding(26)
            }
            Divider()
            HStack {
                Label("Protection ON = AWDL OFF", systemImage: "checkmark.shield.fill")
                    .font(.system(size: 12, weight: .semibold)).foregroundStyle(.mint)
                Spacer()
                Button("Got it") { dismiss() }.buttonStyle(PrimaryGlassButton()).keyboardShortcut(.defaultAction)
            }.padding(.horizontal, 26).padding(.vertical, 17)
        }
        .frame(width: 680, height: 720)
        .tint(.mint)
    }

    private func explanationStep(_ number: String, title: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 13) {
            Text(number).font(.system(size: 12, weight: .bold, design: .rounded)).foregroundStyle(.mint)
                .frame(width: 25, height: 25).background(.mint.opacity(0.12), in: Circle())
            VStack(alignment: .leading, spacing: 7) {
                Text(title).font(.system(size: 15, weight: .semibold))
                Text(text).font(.system(size: 12)).foregroundStyle(.secondary).lineSpacing(4)
            }
        }
    }

    private func packetRow(title: String, caption: String, interrupted: Bool, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title).font(.system(size: 11, weight: .semibold)).foregroundStyle(color)
                Spacer()
                Text(caption).font(.system(size: 10)).foregroundStyle(.secondary)
            }
            HStack(spacing: 5) {
                ForEach(0..<24) { index in
                    let gap = interrupted && [5, 6, 12, 13, 14, 20].contains(index)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(gap ? color.opacity(0.06) : color.opacity(0.7))
                        .overlay(RoundedRectangle(cornerRadius: 3).stroke(gap ? color.opacity(0.22) : .clear, style: StrokeStyle(lineWidth: 1, dash: [2, 2])))
                        .frame(height: 16)
                }
            }.accessibilityHidden(true)
        }
    }
}
