import EnsembleCore
import Foundation
import UIKit

/// Detects installed streaming apps on Apple TV using LSApplicationQueriesSchemes + UIApplication.canOpenURL
/// and hands off playback to those apps via UIApplication.open(deepLinkURL).
@MainActor
final class TVInstalledAppsService {
    func scanInstalledApps() -> [InstalledAppStatus] {
        StreamingAppID.allCases.map { appID in
            if appID == .ensemble {
                return InstalledAppStatus(
                    appID: appID,
                    displayName: appID.displayName,
                    urlScheme: nil,
                    isInstalled: true
                )
            }
            guard let scheme = appID.urlScheme,
                  let probeURL = URL(string: "\(scheme)://") else {
                return InstalledAppStatus(
                    appID: appID,
                    displayName: appID.displayName,
                    urlScheme: appID.urlScheme,
                    isInstalled: false
                )
            }
            let installed = UIApplication.shared.canOpenURL(probeURL)
            return InstalledAppStatus(
                appID: appID,
                displayName: appID.displayName,
                urlScheme: scheme,
                isInstalled: installed
            )
        }
    }

    /// Launches the target installed streaming app directly to the item's deep link (or universal link fallback).
    func openInExternalApp(_ provider: MediaProviderLink) async -> Bool {
        if let deepURL = URL(string: provider.deepLinkURL) {
            let opened = await UIApplication.shared.open(deepURL, options: [:])
            if opened {
                return true
            }
        }
        if let universalString = provider.universalLinkURL,
           let universalURL = URL(string: universalString) {
            return await UIApplication.shared.open(universalURL, options: [:])
        }
        return false
    }
}
