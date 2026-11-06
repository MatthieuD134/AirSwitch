import Foundation

MainActor.assumeIsolated {
    if !CLIRunner.handle() {
        AirSwitchDaemon.run()
    }
}
