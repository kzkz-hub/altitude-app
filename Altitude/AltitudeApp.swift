import SwiftUI

@main
struct AltitudeApp: App {
    @State private var altitudeManager = AltitudeManager()
    @State private var liveActivity = LiveActivityController()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(altitudeManager)
                .environment(liveActivity)
                .onAppear {
                    let controller = liveActivity
                    altitudeManager.onUpdate = { state in
                        controller.update(with: state)
                    }
                    altitudeManager.start()
                }
        }
    }
}
