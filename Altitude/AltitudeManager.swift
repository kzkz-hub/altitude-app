import CoreLocation
import CoreMotion
import Foundation
import Observation

/// 気圧計 (CMAltimeter の絶対高度) と GPS (CLLocation) から標高を取得する。
/// 気圧計が使える端末ではそちらを優先し、使えない場合は GPS の高度を使う。
@MainActor
@Observable
final class AltitudeManager: NSObject {
    enum Source: String {
        case barometer = "気圧計+GPS"
        case gps = "GPS"
    }

    private(set) var altitude: Double?
    private(set) var accuracy: Double?
    private(set) var source: Source = .gps
    private(set) var updatedAt: Date?
    private(set) var authorizationStatus: CLAuthorizationStatus = .notDetermined
    private(set) var errorMessage: String?
    private(set) var isRunning = false

    /// 標高が更新されるたびに呼ばれる (Live Activity の更新に使う)
    @ObservationIgnored var onUpdate: ((AltitudeActivityAttributes.ContentState) -> Void)?

    @ObservationIgnored private let locationManager = CLLocationManager()
    @ObservationIgnored private let altimeter = CMAltimeter()
    @ObservationIgnored private var lastBarometerDate: Date?

    /// この秒数以内に気圧計の値が来ていれば GPS の値では上書きしない
    private let barometerFreshness: TimeInterval = 10

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = kCLDistanceFilterNone
        locationManager.activityType = .fitness
        locationManager.pausesLocationUpdatesAutomatically = false
        authorizationStatus = locationManager.authorizationStatus
    }

    var currentState: AltitudeActivityAttributes.ContentState? {
        guard let altitude else { return nil }
        return .init(
            altitude: altitude,
            accuracy: accuracy,
            sourceName: source.rawValue,
            updatedAt: updatedAt ?? Date()
        )
    }

    func start() {
        switch locationManager.authorizationStatus {
        case .notDetermined:
            // 許可されたら locationManagerDidChangeAuthorization から開始する
            locationManager.requestWhenInUseAuthorization()
        case .restricted, .denied:
            errorMessage = "位置情報の利用が許可されていません。設定アプリから許可してください。"
        case .authorizedWhenInUse, .authorizedAlways:
            beginUpdates()
        @unknown default:
            break
        }
    }

    func stop() {
        locationManager.stopUpdatingLocation()
        altimeter.stopAbsoluteAltitudeUpdates()
        isRunning = false
    }

    private func beginUpdates() {
        guard !isRunning else { return }
        isRunning = true
        errorMessage = nil

        // Info.plist の UIBackgroundModes に location があるので、
        // 前面で開始していればバックグラウンド・ロック中も更新が続く (青い位置情報インジケータが出る)
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.showsBackgroundLocationIndicator = true
        locationManager.startUpdatingLocation()

        if CMAltimeter.isAbsoluteAltitudeAvailable() {
            altimeter.startAbsoluteAltitudeUpdates(to: .main) { [weak self] data, error in
                MainActor.assumeIsolated {
                    guard let self else { return }
                    if let data {
                        self.handleBarometer(data)
                    } else if let error {
                        // 気圧計が使えなくても GPS で続行する
                        print("Altimeter error: \(error)")
                    }
                }
            }
        }
    }

    private func handleBarometer(_ data: CMAbsoluteAltitudeData) {
        lastBarometerDate = Date()
        apply(altitude: data.altitude, accuracy: data.accuracy, source: .barometer)
    }

    private func handleLocation(_ location: CLLocation) {
        // verticalAccuracy が負の場合は高度が無効
        guard location.verticalAccuracy >= 0 else { return }
        if let lastBarometerDate, Date().timeIntervalSince(lastBarometerDate) < barometerFreshness {
            return
        }
        apply(altitude: location.altitude, accuracy: location.verticalAccuracy, source: .gps)
    }

    private func apply(altitude: Double, accuracy: Double?, source: Source) {
        self.altitude = altitude
        self.accuracy = accuracy
        self.source = source
        self.updatedAt = Date()
        if let state = currentState {
            onUpdate?(state)
        }
    }
}

extension AltitudeManager: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            self.authorizationStatus = status
            switch status {
            case .authorizedWhenInUse, .authorizedAlways:
                self.beginUpdates()
            case .denied, .restricted:
                self.stop()
                self.errorMessage = "位置情報の利用が許可されていません。設定アプリから許可してください。"
            default:
                break
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task { @MainActor in
            self.handleLocation(location)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        let message = error.localizedDescription
        Task { @MainActor in
            self.errorMessage = "位置情報の取得に失敗しました: \(message)"
        }
    }
}
