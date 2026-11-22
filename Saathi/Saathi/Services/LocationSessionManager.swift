import Foundation
import CoreLocation
import UIKit
import SaathiCore

/// Manages CoreLocation When-In-Use + temporary full accuracy using modern iOS async APIs.
/// Exact coordinates are kept strictly in RAM and wiped immediately when the session ends.
@MainActor
@Observable
final class LocationSessionManager {
    private var serviceSession: CLServiceSession?
    private var updatesTask: Task<Void, Never>?

    private(set) var isRunning: Bool = false
    private(set) var currentCoordinate: EphemeralCoordinate?
    private(set) var sessionStartedAt: Date?
    private(set) var authorizationNotice: String?

    private let mockMode: Bool

    init(mockMode: Bool = false) {
        self.mockMode = mockMode
    }

    func start(onCoordinateUpdate: @escaping @MainActor (EphemeralCoordinate) -> Void) {
        guard !isRunning else { return }
        isRunning = true
        sessionStartedAt = Date()
        authorizationNotice = nil

        if mockMode {
            // Simulated real-time walk along the bundled Hampi GPX route (in-memory only),
            // so the demo moves past landmarks instead of standing still.
            let route = Self.mockRoute()
            if let first = route.first {
                self.currentCoordinate = first
                onCoordinateUpdate(first)
            }
            updatesTask = Task { [weak self] in
                for point in route.dropFirst() {
                    try? await Task.sleep(for: .seconds(Self.mockStepSeconds))
                    guard let self, self.isRunning, !Task.isCancelled else { return }
                    self.currentCoordinate = point
                    onCoordinateUpdate(point)
                }
            }
            return
        }

        // Declarative CoreLocation service session: When-In-Use (works with Allow Once) + temporary full accuracy
        self.serviceSession = CLServiceSession(
            authorization: .whenInUse,
            fullAccuracyPurposeKey: "SaathiLiveTourAccuracy"
        )

        updatesTask = Task { [weak self] in
            do {
                let updates = CLLocationUpdate.liveUpdates(.otherNavigation)
                for try await update in updates {
                    guard let self, self.isRunning, !Task.isCancelled else { break }
                    if let location = update.location {
                        let coord = EphemeralCoordinate(
                            latitude: location.coordinate.latitude,
                            longitude: location.coordinate.longitude
                        )
                        self.currentCoordinate = coord
                        onCoordinateUpdate(coord)
                    }
                    if update.authorizationDenied || update.authorizationRestricted {
                        self.authorizationNotice = "Location access denied. Touch mode remains available without GPS."
                    }
                }
            } catch {
                self?.authorizationNotice = "Location updates paused: \(error.localizedDescription)"
            }
        }
    }

    /// Immediately stops all location updates and wipes in-memory coordinates.
    @discardableResult
    func stopAndWipe() -> TimeInterval {
        let elapsed = sessionStartedAt.map { Date().timeIntervalSince($0) } ?? 0
        updatesTask?.cancel()
        updatesTask = nil
        serviceSession?.invalidate()
        serviceSession = nil
        isRunning = false
        currentCoordinate = nil
        sessionStartedAt = nil
        return elapsed
    }

    /// Seconds between simulated GPX points in mock mode.
    static let mockStepSeconds: Double = 8

    /// Waypoints from Simulation/Hampi_Vittala.gpx (bundled), with a fixed fallback.
    static func mockRoute() -> [EphemeralCoordinate] {
        let fallback = [EphemeralCoordinate(latitude: 15.3425, longitude: 76.4756)]
        guard let url = Bundle.main.url(forResource: "Hampi_Vittala", withExtension: "gpx"),
              let text = try? String(contentsOf: url, encoding: .utf8),
              let regex = try? NSRegularExpression(pattern: #"lat="(-?[0-9.]+)"\s+lon="(-?[0-9.]+)""#) else {
            return fallback
        }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        let points: [EphemeralCoordinate] = regex.matches(in: text, range: range).compactMap { match in
            guard let latRange = Range(match.range(at: 1), in: text),
                  let lonRange = Range(match.range(at: 2), in: text),
                  let lat = Double(text[latRange]), let lon = Double(text[lonRange]) else { return nil }
            return EphemeralCoordinate(latitude: lat, longitude: lon)
        }
        // Start at the Stone Chariot so the first narration is immediate.
        let startIndex = points.firstIndex { abs($0.latitude - 15.3425) < 0.0001 && abs($0.longitude - 76.4756) < 0.0001 } ?? 0
        let ordered = Array(points[startIndex...])
        return ordered.isEmpty ? fallback : ordered
    }

    func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}
