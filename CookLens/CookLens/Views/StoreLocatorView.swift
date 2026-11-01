//
//  StoreLocatorView.swift
//  CookLens
//

import SwiftUI
import MapKit

struct StoreLocatorView: View {
    let recipe: Recipe
    @Environment(\.dismiss) private var dismiss
    @State private var position: MapCameraPosition = .userLocation(fallback: .automatic)
    @State private var selectedStore: MarketStore?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Total Door-to-Plate Time Breakdown
                TimeBreakdownBanner(prepTime: recipe.prepTime, missingCount: recipe.additionalPantryItemsNeeded.count)

                // Interactive MapKit View
                Map(position: $position, selection: $selectedStore) {
                    UserAnnotation()
                    ForEach(SampleMarkets.stores) { store in
                        Marker(store.name, coordinate: store.coordinate)
                            .tint(store.stocksAllNeeded ? .green : .orange)
                            .tag(store)
                    }
                }
                .mapControls {
                    MapUserLocationButton()
                    MapCompass()
                }
                .frame(maxHeight: 280)

                // Store Cards List
                List(SampleMarkets.stores) { store in
                    StoreRowView(store: store, missingItems: recipe.additionalPantryItemsNeeded)
                        .onTapGesture {
                            selectedStore = store
                        }
                }
                .listStyle(.plain)
            }
            .navigationTitle("Ingredients & Stores")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

struct MarketStore: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let coordinate: CLLocationCoordinate2D
    let driveMinutes: Int
    let trafficCondition: String
    let stocksAllNeeded: Bool

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: MarketStore, rhs: MarketStore) -> Bool {
        lhs.id == rhs.id
    }
}

struct SampleMarkets {
    static let stores = [
        MarketStore(name: "Whole Foods Market", coordinate: CLLocationCoordinate2D(latitude: 37.7824, longitude: -122.4001), driveMinutes: 8, trafficCondition: "Moderate Traffic", stocksAllNeeded: true),
        MarketStore(name: "Bi-Rite Gourmet Market", coordinate: CLLocationCoordinate2D(latitude: 37.7615, longitude: -122.4257), driveMinutes: 11, trafficCondition: "Light Traffic", stocksAllNeeded: true),
        MarketStore(name: "Trader Joe's", coordinate: CLLocationCoordinate2D(latitude: 37.7710, longitude: -122.4102), driveMinutes: 6, trafficCondition: "Light Traffic", stocksAllNeeded: false)
    ]
}

struct TimeBreakdownBanner: View {
    let prepTime: String
    let missingCount: Int

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Total Ready Time: ~48 mins")
                    .font(.subheadline.bold())
                Text("Travel (16m) • Shop (8m) • Cook (\(prepTime)) • Seasonal (+2m)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "car.fill")
                .foregroundStyle(.orange)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
    }
}

struct StoreRowView: View {
    let store: MarketStore
    let missingItems: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(store.name)
                    .font(.subheadline.bold())
                Spacer()
                Text("\(store.driveMinutes)m drive")
                    .font(.caption.bold())
                    .foregroundStyle(.orange)
            }
            Text(store.stocksAllNeeded ? "In Stock: All \(missingItems.count) pantry items" : "Limited stock on specialty spices")
                .font(.caption)
                .foregroundStyle(store.stocksAllNeeded ? .green : .secondary)
        }
        .padding(.vertical, 4)
    }
}
