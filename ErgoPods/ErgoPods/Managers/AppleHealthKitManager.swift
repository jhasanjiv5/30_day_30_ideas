//
//  AppleHealthKitManager.swift
//  ErgoPods
//
//  Apple HealthKit synchronization for heart rate, step count, and standing hours
//

import Foundation
import HealthKit
import Combine

@MainActor
public final class AppleHealthKitManager: ObservableObject {
    @Published public var currentHeartRate: Double = 72.0
    @Published public var restingHeartRate: Double = 65.0
    @Published public var stepCountToday: Int = 2450
    @Published public var standingHoursToday: Int = 6
    @Published public var isAuthorized: Bool = false
    
    private let healthStore = HKHealthStore()
    
    public init() {
        requestAuthorization()
    }
    
    public func requestAuthorization() {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        
        let readTypes: Set<HKObjectType> = [
            HKQuantityType.quantityType(forIdentifier: .heartRate)!,
            HKQuantityType.quantityType(forIdentifier: .restingHeartRate)!,
            HKQuantityType.quantityType(forIdentifier: .stepCount)!,
            HKCategoryType.categoryType(forIdentifier: .appleStandHour)!
        ]
        
        healthStore.requestAuthorization(toShare: nil, read: readTypes) { [weak self] success, error in
            DispatchQueue.main.async {
                self?.isAuthorized = success
                if success {
                    self?.queryTodayMetrics()
                    self?.startBackgroundHeartRateObserver()
                }
            }
        }
    }
    
    public func queryTodayMetrics() {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: Date(), options: .strictStartDate)
        
        let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
        let stepQuery = HKStatisticsQuery(quantityType: stepType, quantitySamplePredicate: predicate, options: .cumulativeSum) { [weak self] _, statistics, _ in
            if let sum = statistics?.sumQuantity() {
                let steps = Int(sum.doubleValue(for: HKUnit.count()))
                DispatchQueue.main.async {
                    self?.stepCountToday = steps
                }
            }
        }
        healthStore.execute(stepQuery)
    }
    
    private func startBackgroundHeartRateObserver() {
        let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate)!
        let query = HKObserverQuery(sampleType: heartRateType, predicate: nil) { [weak self] _, completionHandler, error in
            guard error == nil else { return }
            self?.queryLatestHeartRate()
            completionHandler()
        }
        healthStore.execute(query)
    }
    
    private func queryLatestHeartRate() {
        let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate)!
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        let sampleQuery = HKSampleQuery(sampleType: heartRateType, predicate: nil, limit: 1, sortDescriptors: [sortDescriptor]) { [weak self] _, samples, _ in
            guard let sample = samples?.first as? HKQuantitySample else { return }
            let bpm = sample.quantity.doubleValue(for: HKUnit(from: "count/min"))
            DispatchQueue.main.async {
                self?.currentHeartRate = bpm
            }
        }
        healthStore.execute(sampleQuery)
    }
}
