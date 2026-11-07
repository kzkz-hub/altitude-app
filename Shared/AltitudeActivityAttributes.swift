import ActivityKit
import Foundation

/// Live Activity (ロック画面 / Dynamic Island) で共有するデータ。
/// アプリ本体とウィジェット拡張の両方でコンパイルされます。
struct AltitudeActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        /// 標高 (m, 海抜)
        var altitude: Double
        /// 推定誤差 (m)。不明な場合は nil
        var accuracy: Double?
        /// 測定ソースの表示名
        var sourceName: String
        /// 最終更新時刻
        var updatedAt: Date
    }
}

extension AltitudeActivityAttributes.ContentState {
    var altitudeText: String {
        "\(Int(altitude.rounded())) m"
    }

    var accuracyText: String? {
        guard let accuracy else { return nil }
        return "±\(Int(accuracy.rounded())) m"
    }
}
