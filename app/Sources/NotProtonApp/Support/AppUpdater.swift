import Sparkle

@MainActor
final class AppUpdater {

    private let controller: SPUStandardUpdaterController?

    var isEnabled: Bool { controller != nil }

    init() {
        // An upstream update would replace this compatibility port. A fork
        // must opt in after configuring its own compatible release feed.
        guard Bundle.main.object(forInfoDictionaryKey: "NPEnableUpstreamUpdates") as? Bool == true else {
            controller = nil
            return
        }
        #if DEBUG
        let scheduling = false
        #else
        let scheduling = true
        #endif
        controller = SPUStandardUpdaterController(
            startingUpdater: scheduling,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
    }

    func check() {
        #if !DEBUG
        controller?.checkForUpdates(nil)
        #endif
    }
}
