// CarMedia — MIT © 2026 CarMedia contributors (see LICENSE).
// UIKit entry point. We deliberately use the classic lifecycle so the
// Info.plist scene manifest — including the CarPlay *window* scene role — is
// honoured exactly as in the verified reference (cafari-lite, MIT). Phone UI
// is still SwiftUI, hosted by PhoneSceneDelegate.

import UIKit

UIApplicationMain(
    CommandLine.argc,
    CommandLine.unsafeArgv,
    nil,
    NSStringFromClass(AppDelegate.self)
)
