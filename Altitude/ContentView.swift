import SwiftUI
import UIKit

struct ContentView: View {
    @Environment(AltitudeManager.self) private var altitude
    @Environment(LiveActivityController.self) private var liveActivity
    @AppStorage("keepScreenOn") private var keepScreenOn = false
    @AppStorage("autoStartLiveActivity") private var autoStartLiveActivity = true

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Spacer()
                altitudeDisplay
                Spacer()
                controls
            }
            .padding()
            .navigationTitle("現在地の標高")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear { applyKeepScreenOn() }
        .onChange(of: keepScreenOn) { applyKeepScreenOn() }
        .onChange(of: altitude.altitude != nil) { _, hasValue in
            // 初回の標高が取れたら自動でロック画面表示を開始
            if hasValue, autoStartLiveActivity, !liveActivity.isActive, let state = altitude.currentState {
                liveActivity.start(with: state)
            }
        }
    }

    private var altitudeDisplay: some View {
        VStack(spacing: 12) {
            Image(systemName: "mountain.2.fill")
                .font(.system(size: 48))
                .foregroundStyle(.tint)

            if let value = altitude.altitude {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(Int(value.rounded()))")
                        .font(.system(size: 96, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                        .animation(.default, value: Int(value.rounded()))
                    Text("m")
                        .font(.system(size: 36, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                HStack(spacing: 12) {
                    if let accuracy = altitude.accuracy {
                        Label("±\(Int(accuracy.rounded())) m", systemImage: "scope")
                    }
                    Label(altitude.source.rawValue, systemImage: altitude.source == .barometer ? "barometer" : "location.fill")
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
                if let updatedAt = altitude.updatedAt {
                    Text("更新: \(updatedAt.formatted(date: .omitted, time: .standard))")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            } else if let error = altitude.errorMessage {
                Text(error)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.red)
                Button("設定を開く") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
            } else {
                ProgressView("標高を測定中…")
            }
        }
    }

    private var controls: some View {
        VStack(spacing: 16) {
            Toggle(isOn: liveActivityBinding) {
                Label("ロック画面・Dynamic Islandに表示", systemImage: "lock.iphone")
            }
            .disabled(altitude.altitude == nil)

            Toggle(isOn: $keepScreenOn) {
                Label("画面を常にオン（スリープしない）", systemImage: "sun.max")
            }

            if let error = liveActivity.errorMessage {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private var liveActivityBinding: Binding<Bool> {
        Binding(
            get: { liveActivity.isActive },
            set: { isOn in
                autoStartLiveActivity = isOn
                if isOn, let state = altitude.currentState {
                    liveActivity.start(with: state)
                } else {
                    liveActivity.stop()
                }
            }
        )
    }

    private func applyKeepScreenOn() {
        UIApplication.shared.isIdleTimerDisabled = keepScreenOn
    }
}
