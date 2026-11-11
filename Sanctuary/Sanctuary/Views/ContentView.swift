//
//  ContentView.swift
//  Sanctuary
//
//  Main Navigation Container with TabBar
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = TherapySessionViewModel()

    var body: some View {
        TabView {
            NavigationStack {
                CheckInView(viewModel: viewModel)
            }
            .tabItem {
                Label("Session", systemImage: "moon.stars.fill")
            }

            NavigationStack {
                JournalHistoryView()
            }
            .tabItem {
                Label("Journal", systemImage: "book.pages.fill")
            }

            NavigationStack {
                HealthKitAnalyticsView()
            }
            .tabItem {
                Label("State of Mind", systemImage: "heart.text.square.fill")
            }

            NavigationStack {
                RoutineSettingsView()
            }
            .tabItem {
                Label("Routine", systemImage: "bell.badge.fill")
            }
        }
        .tint(.indigo)
        .onAppear {
            viewModel.setContext(modelContext)
        }
    }
}
