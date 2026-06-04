import CoreGraphics
import Foundation

let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []

for window in windows {
    let owner = window[kCGWindowOwnerName as String] as? String ?? ""
    let pid = window[kCGWindowOwnerPID as String] as? Int ?? 0
    let name = window[kCGWindowName as String] as? String ?? ""
    let layer = window[kCGWindowLayer as String] as? Int ?? 0
    let bounds = window[kCGWindowBounds as String] as? [String: Any] ?? [:]
    if owner.localizedCaseInsensitiveContains("ShouldRest") ||
        name.localizedCaseInsensitiveContains("ShouldRest") ||
        name.localizedCaseInsensitiveContains("Welcome") {
        print("owner=\(owner) pid=\(pid) name=\(name) layer=\(layer) bounds=\(bounds)")
    }
}
