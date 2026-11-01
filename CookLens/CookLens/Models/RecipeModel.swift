//
//  RecipeModel.swift
//  CookLens
//

import Foundation

struct Recipe: Identifiable, Codable, Equatable, Sendable {
    var id: String
    let title: String
    let prepTime: String
    let detectedIngredients: [String]
    let additionalPantryItemsNeeded: [String]
    let steps: [String]
    var youtubeShortsUrl: String?
    var instagramReelUrl: String?
}
