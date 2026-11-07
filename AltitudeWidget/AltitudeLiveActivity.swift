import ActivityKit
import SwiftUI
import WidgetKit

/// ロック画面と Dynamic Island に標高を表示する Live Activity
struct AltitudeLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: AltitudeActivityAttributes.self) { context in
            LockScreenAltitudeView(state: context.state, isStale: context.isStale)
                .activityBackgroundTint(Color.black.opacity(0.55))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label("標高", systemImage: "mountain.2.fill")
                        .font(.headline)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.state.sourceName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.state.altitudeText)
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .monospacedDigit()
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        if let accuracy = context.state.accuracyText {
                            Text(accuracy)
                        }
                        Spacer()
                        Text("更新 \(context.state.updatedAt.formatted(date: .omitted, time: .shortened))")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            } compactLeading: {
                Image(systemName: "mountain.2.fill")
                    .foregroundStyle(.green)
            } compactTrailing: {
                Text(context.state.altitudeText)
                    .monospacedDigit()
                    .foregroundStyle(.green)
            } minimal: {
                Text("\(Int(context.state.altitude.rounded()))")
                    .monospacedDigit()
                    .foregroundStyle(.green)
            }
        }
    }
}

private struct LockScreenAltitudeView: View {
    let state: AltitudeActivityAttributes.ContentState
    let isStale: Bool

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: "mountain.2.fill")
                .font(.system(size: 32))
                .foregroundStyle(.green)
            VStack(alignment: .leading, spacing: 2) {
                Text("現在地の標高")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
                Text(state.altitudeText)
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(isStale ? .white.opacity(0.5) : .white)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                if let accuracy = state.accuracyText {
                    Text(accuracy)
                }
                Text(state.sourceName)
                Text(isStale ? "更新停止中" : state.updatedAt.formatted(date: .omitted, time: .shortened))
            }
            .font(.caption)
            .foregroundStyle(.white.opacity(0.7))
        }
        .padding()
    }
}
