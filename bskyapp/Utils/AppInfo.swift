import Foundation

/// 設定画面の「このアプリについて」に出すバージョンと著作権表記
enum AppInfo {
  static let copyright = "© 2026 akagisrapid. All rights reserved."

  /// 例: "1.2 (1)"。ビルド番号が無いときはバージョンだけ、どちらも無いときは "-"
  static var versionString: String {
    versionString(from: Bundle.main.infoDictionary)
  }

  static func versionString(from info: [String: Any]?) -> String {
    let version = info?["CFBundleShortVersionString"] as? String
    let build = info?["CFBundleVersion"] as? String
    switch (version, build) {
    case let (version?, build?): return "\(version) (\(build))"
    case let (version?, nil): return version
    case let (nil, build?): return "(\(build))"
    case (nil, nil): return "-"
    }
  }
}
