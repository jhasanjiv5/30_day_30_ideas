//
//  HealthKitManager.swift
//  AquaWatch Watch App
//
//  HealthKit Dietary Water Background Recording & Cloud Sync
//

import Foundation
import HealthKit

public class HealthKitManager: ObservableObject {
    public static let shared = HealthKitManager()
    private let healthStore = HKHealthStore()
    
    private let waterType = HKQuantityType.quantityType(forIdentifier: .dietaryWater)!
    
    public func requestAuthorization() async -> Bool {
        guard HKHealthStore.isHealthDataAvailable() else { return false }
        
        do {
            try await healthStore.requestAuthorization(toShare: [waterType], read: [waterType])
            return true
        } catch {
            print("HealthKit Authorization Error: \(error.localizedDescription)")
            return false
        }
    }
    
    public func logWater(milliliters: Int, date: Date = Date()) async throws {
        let quantity = HKQuantity(unit: .literUnit(with: .milli), doubleValue: Double(milliliters))
        let sample = HKQuantitySample(
            type: waterType,
            quantity: quantity,
            start: date,
            end: date,
            metadata: [
                HKMetadataKeySyncIdentifier: UUID().uuidString,
                "HKDeviceSource": "AppleWatchUltra_AquaWatch",
                "HKGestureVerified": true
            ]
        )
        
        try await healthStore.save(sample)
    }
}