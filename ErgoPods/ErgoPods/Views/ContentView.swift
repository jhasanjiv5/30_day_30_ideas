//
//  ContentView.swift
//  ErgoPods
//
//  Main Navigation with Cupertino TabView & Dark Mode
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var motion: HeadphoneMotionManager
    @EnvironmentObject var health: AppleHealthKitManager
    @State private var selectedTab = 0
    @State private var showOnboarding = false
    
    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                PostureTrackingView(showOnboarding: $showOnboarding)
                    .navigationTitle("ErgoPods")
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button {
                                showOnboarding = true
                            } label: {
                                Image(systemName: "slider.horizontal.3")
                            }
                        }
                    }
            }
            .tabItem {
                Label("Posture", systemImage: "headphones")
            }
            .tag(0)
            
            NavigationStack {
                HealthVitalsView()
                    .navigationTitle("Apple Health")
            }
            .tabItem {
                Label("HealthKit", systemImage: "heart.fill")
            }
            .tag(1)
            
            NavigationStack {
                PhysiotherapistView()
                    .navigationTitle("Physio AI")
            }
            .tabItem {
                Label("Physio", systemImage: "brain.head.profile")
            }
            .tag(2)
            
            NavigationStack {
                BadgesView()
                    .navigationTitle("Badges")
            }
            .tabItem {
                Label("Badges", systemImage: "medal.fill")
            }
            .tag(3)
        }
        .tint(.blue)
        .sheet(isPresented: $showOnboarding) {
            AirPodsOnboardingView(isPresented: $showOnboarding)
        }
    }
}
