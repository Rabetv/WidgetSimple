import Foundation

/// What this build can do on this iPhone.
enum Features {
    /// The iOS 27 Direct Launcher widget: apps picked in Edit Widget open directly.
    /// Needs a build made with the iOS 27 SDK (SDK27) and iOS 27 on the device.
    static var directLaunch: Bool {
        #if SDK27
        if #available(iOS 27.0, *) { return true }
        #endif
        return false
    }
}
