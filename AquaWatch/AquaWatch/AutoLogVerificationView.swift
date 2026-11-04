//
//  AutoLogVerificationView.swift
//  AquaWatch Watch App
//
//  Questions what was drunk and how much in ounces or liters
//  Includes Digital Crown binding & watchOS Double Tap gesture
//

import SwiftUI
import WatchKit

public enum VolumeMetric: String, CaseIterable, Identifiable {
    case ounces = "fl oz"
    case liters = "Liters"
    public var id: String { rawValue }
}

public enum BeverageChoice: String, CaseIterable, Identifiable {
    case water = "Pure Water"
    case electrolyte = "Electrolyte"
    case sparkling = "Sparkling"
    case tea = "Green Tea"
    case coffee = "Coffee"
    public var id: String { rawValue }
    
    public var defaultOz: Double {
        switch self {
        case .water: return 8.0
        case .electrolyte: return 12.0
        case .sparkling: return 11.0
        case .tea: return 8.0
        case .coffee: return 6.0
        }
    }
}

struct AutoLogVerificationView: View {
    @ObservedObject var classifier: MotionGestureClassifier
    @Binding var isPresented: Bool
    var metric: VolumeMetric = .ounces
    let onConfirmed: (Int, BeverageChoice) -> Void
    
    @State private var step: Int = 1 // 1: What did you drink?, 2: How much?
    @State private var selectedBeverage: BeverageChoice = .water
    @State private var amountOz: Double = 8.0
    @State private var amountLiters: Double = 0.25
    @State private var timeRemaining: Int = 8
    @State private var timer: Timer?
    
    var body: some View {
        VStack(spacing: 6) {
            // Header
            HStack(spacing: 4) {
                Image(systemName: "drop.fill")
                    .foregroundColor(.cyan)
                    .font(.caption2)
                
                Text(step == 1 ? "1/2: WHAT DID YOU DRINK?" : "2/2: HOW MUCH?")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("\(timeRemaining)s")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(.cyan)
            }
            .padding(.top, 2)
            
            if step == 1 {
                // QUESTION 1: WHAT DID YOU DRINK?
                List(BeverageChoice.allCases) { beverage in
                    Button {
                        selectedBeverage = beverage
                        amountOz = beverage.defaultOz
                        amountLiters = (beverage.defaultOz * 29.5735) / 1000.0
                        step = 2
                    } label: {
                        HStack {
                            Circle()
                                .fill(beverage == .water ? Color.cyan : Color.mint)
                                .frame(width: 8, height: 8)
                            Text(beverage.rawValue)
                                .font(.system(size: 11, weight: .medium))
                            Spacer()
                            if selectedBeverage == beverage {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.cyan)
                                    .font(.caption2)
                            }
                        }
                    }
                }
                .listStyle(.carousel)
            } else {
                // QUESTION 2: HOW MUCH? (IN OUNCES OR LITERS)
                Spacer()
                
                VStack(spacing: 1) {
                    Text(selectedBeverage.rawValue)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.secondary)
                    
                    if metric == .ounces {
                        Text(String(format: "+%.1f", amountOz))
                            .font(.system(size: 32, weight: .black, design: .rounded))
                            .foregroundColor(.cyan)
                        Text("fl oz")
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundColor(.secondary)
                    } else {
                        Text(String(format: "+%.2f", amountLiters))
                            .font(.system(size: 32, weight: .black, design: .rounded))
                            .foregroundColor(.cyan)
                        Text("Liters")
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                }
                .focusable()
                // Bind Digital Crown rotation to adjust volume!
                .digitalCrownRotation(
                    metric == .ounces ? $amountOz : $amountLiters,
                    from: metric == .ounces ? 2.0 : 0.1,
                    through: metric == .ounces ? 32.0 : 1.5,
                    by: metric == .ounces ? 0.5 : 0.05,
                    sensitivity: .medium,
                    isContinuous: false,
                    isHapticFeedbackEnabled: true
                )
                
                Text("Double Tap or tap Confirm to log")
                    .font(.system(size: 8, weight: .medium))
                    .foregroundColor(.secondary)
                
                Spacer()
                
                HStack(spacing: 6) {
                    Button("Back") {
                        step = 1
                    }
                    .buttonStyle(.bordered)
                    .tint(.secondary)
                    
                    Button {
                        confirmLog()
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "checkmark")
                            Text("Confirm")
                        }
                        .font(.system(size: 11, weight: .bold))
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.cyan)
                    .modifier(PrimaryHandGestureShortcut())
                }
            }
        }
        .padding(6)
        .background(Color.black)
        .onAppear {
            startCountdown()
        }
    }

    private struct PrimaryHandGestureShortcut: ViewModifier {
        @ViewBuilder
        func body(content: Content) -> some View {
            if #available(watchOS 11.0, *) {
                content.handGestureShortcut(.primaryAction)
            } else {
                content
            }
        }
    }
    
    private func startCountdown() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if timeRemaining > 1 {
                timeRemaining -= 1
            } else {
                confirmLog()
            }
        }
    }
    
    private func confirmLog() {
        timer?.invalidate()
        WKInterfaceDevice.current().play(.success)
        let finalMl = metric == .ounces ? Int(amountOz * 29.5735) : Int(amountLiters * 1000.0)
        onConfirmed(finalMl, selectedBeverage)
        classifier.clearDetection()
        isPresented = false
    }
}