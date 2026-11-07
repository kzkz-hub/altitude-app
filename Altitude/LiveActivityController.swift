import ActivityKit
import Foundation
import Observation

/// ロック画面 / Dynamic Island に標高を常時表示する Live Activity を管理する。
@MainActor
@Observable
final class LiveActivityController {
    private(set) var isActive = false
    private(set) var errorMessage: String?

    @ObservationIgnored private var activity: Activity<AltitudeActivityAttributes>?
    @ObservationIgnored private var lastSentState: AltitudeActivityAttributes.ContentState?
    @ObservationIgnored private var stateObservation: Task<Void, Never>?

    /// 更新の最小間隔 (秒)。システム側でも頻度は制限される
    private let minInterval: TimeInterval = 5
    /// この変化量 (m) 未満なら、heartbeatInterval 経過まで更新しない
    private let minAltitudeChange: Double = 1
    private let heartbeatInterval: TimeInterval = 60

    var areActivitiesEnabled: Bool {
        ActivityAuthorizationInfo().areActivitiesEnabled
    }

    init() {
        // アプリ再起動時に、前回の Live Activity が残っていれば引き継ぐ
        if let existing = Activity<AltitudeActivityAttributes>.activities.first {
            attach(existing)
        }
    }

    func start(with state: AltitudeActivityAttributes.ContentState) {
        guard activity == nil else { return }
        guard areActivitiesEnabled else {
            errorMessage = "ライブアクティビティがオフです。設定アプリ > 標高 からオンにしてください。"
            return
        }
        do {
            let newActivity = try Activity.request(
                attributes: AltitudeActivityAttributes(),
                content: content(for: state),
                pushType: nil
            )
            lastSentState = state
            errorMessage = nil
            attach(newActivity)
        } catch {
            errorMessage = "ライブアクティビティを開始できませんでした: \(error.localizedDescription)"
        }
    }

    func update(with state: AltitudeActivityAttributes.ContentState) {
        guard let activity else { return }
        if let last = lastSentState {
            let elapsed = state.updatedAt.timeIntervalSince(last.updatedAt)
            let changed = abs(state.altitude - last.altitude) >= minAltitudeChange
                || state.sourceName != last.sourceName
            if elapsed < minInterval { return }
            if !changed && elapsed < heartbeatInterval { return }
        }
        lastSentState = state
        let content = content(for: state)
        Task {
            await activity.update(content)
        }
    }

    func stop() {
        guard let activity else { return }
        let finalContent = lastSentState.map { content(for: $0) }
        Task {
            await activity.end(finalContent, dismissalPolicy: .immediate)
        }
        detach()
    }

    private func content(for state: AltitudeActivityAttributes.ContentState) -> ActivityContent<AltitudeActivityAttributes.ContentState> {
        // 更新が途絶えたら「古い値」と分かるように staleDate を設定
        ActivityContent(state: state, staleDate: state.updatedAt.addingTimeInterval(10 * 60))
    }

    private func attach(_ activity: Activity<AltitudeActivityAttributes>) {
        self.activity = activity
        isActive = true
        stateObservation?.cancel()
        stateObservation = Task { [weak self] in
            for await state in activity.activityStateUpdates {
                if state == .ended || state == .dismissed {
                    self?.detach()
                    break
                }
            }
        }
    }

    private func detach() {
        stateObservation?.cancel()
        stateObservation = nil
        activity = nil
        lastSentState = nil
        isActive = false
    }
}
