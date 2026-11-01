//
//  RecipeCardView.swift
//  CookLens
//

import SwiftUI

struct RecipeCardView: View {
    let recipe: Recipe
    var onStartCooking: (() -> Void)? = nil
    var onLocateStores: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(recipe.title)
                    .font(.title2.bold())
                Spacer()
                Label(recipe.prepTime, systemImage: "clock")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.ultraThinMaterial, in: Capsule())
            }

            // Quick Video Guides: YouTube Shorts & Instagram Reels
            HStack(spacing: 8) {
                if let yt = recipe.youtubeShortsUrl, let url = URL(string: yt) {
                    Link(destination: url) {
                        Label("YouTube Short", systemImage: "play.rectangle.fill")
                            .font(.caption2.bold())
                            .foregroundStyle(.red)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.red.opacity(0.12), in: Capsule())
                    }
                }
                if let ig = recipe.instagramReelUrl, let url = URL(string: ig) {
                    Link(destination: url) {
                        Label("Instagram Reel", systemImage: "camera.fill")
                            .font(.caption2.bold())
                            .foregroundStyle(.pink)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.pink.opacity(0.12), in: Capsule())
                    }
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Detected in Photo:")
                    .font(.subheadline.bold())
                    .foregroundStyle(.secondary)
                WrappingHStack(models: recipe.detectedIngredients, color: .green)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Pantry Staples Needed:")
                    .font(.subheadline.bold())
                    .foregroundStyle(.secondary)
                WrappingHStack(models: recipe.additionalPantryItemsNeeded, color: .orange)
            }

            Divider()

            Text("Steps:")
                .font(.subheadline.bold())
                .foregroundStyle(.secondary)

            ForEach(Array(recipe.steps.enumerated()), id: \.offset) { index, step in
                HStack(alignment: .top, spacing: 8) {
                    Text("\(index + 1).")
                        .font(.body.monospacedDigit().bold())
                        .foregroundStyle(.tint)
                    Text(step)
                        .font(.subheadline)
                }
            }

            HStack(spacing: 10) {
                if let onLocateStores {
                    Button(action: onLocateStores) {
                        Label("Find Missing Items", systemImage: "map.fill")
                            .font(.subheadline.bold())
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(.tertiarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
                            .foregroundStyle(.primary)
                    }
                }

                if let onStartCooking {
                    Button(action: onStartCooking) {
                        Label("Start Cook", systemImage: "play.fill")
                            .font(.subheadline.bold())
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 14))
                            .foregroundStyle(.white)
                    }
                }
            }
            .padding(.top, 8)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 3)
    }
}

struct WrappingHStack: View {
    let models: [String]
    let color: Color

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(models, id: \.self) { item in
                    Text(item)
                        .font(.caption.weight(.medium))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(color.opacity(0.15))
                        .foregroundStyle(color)
                        .clipShape(Capsule())
                }
            }
        }
    }
}
