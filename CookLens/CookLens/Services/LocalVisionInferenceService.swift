//
//  LocalVisionInferenceService.swift
//  CookLens
//

import UIKit
import Vision

protocol IngredientRecipeServiceProtocol: Sendable {
    func analyzeIngredientsAndGenerateRecipes(from image: UIImage) async throws -> [Recipe]
}

final class LocalVisionInferenceService: IngredientRecipeServiceProtocol, Sendable {
    func analyzeIngredientsAndGenerateRecipes(from image: UIImage) async throws -> [Recipe] {
        guard let cgImage = image.cgImage else {
            throw NSError(
                domain: "VisionInference",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "The captured photo could not be read."]
            )
        }

        let request = VNClassifyImageRequest()
        try VNImageRequestHandler(cgImage: cgImage, options: [:]).perform([request])

        let labels = (request.results ?? [])
            .filter { $0.confidence >= 0.05 }
            .map(\.identifier)
        let ingredients = IngredientCatalog.ingredients(from: labels)

        guard !ingredients.isEmpty else {
            throw NSError(
                domain: "VisionInference",
                code: -2,
                userInfo: [NSLocalizedDescriptionKey: "Apple Vision could not identify common ingredients in this photo. Try a closer, well-lit photo of the food."]
            )
        }

        let recipes = RecipeSuggestionGenerator.recipes(using: ingredients)
        guard !recipes.isEmpty else {
            throw NSError(
                domain: "VisionInference",
                code: -3,
                userInfo: [NSLocalizedDescriptionKey: "Apple Vision recognized \(ingredients.joined(separator: ", ")), but CookLens has no recipe suggestion for those ingredients yet."]
            )
        }

        return recipes
    }
}

private enum IngredientCatalog {
    private struct Definition {
        let name: String
        let aliases: [String]
    }

    private static let definitions = [
        Definition(name: "Apple", aliases: ["apple"]),
        Definition(name: "Avocado", aliases: ["avocado"]),
        Definition(name: "Banana", aliases: ["banana"]),
        Definition(name: "Bell Pepper", aliases: ["bell pepper", "capsicum", "pepper"]),
        Definition(name: "Bread", aliases: ["bread", "loaf"]),
        Definition(name: "Broccoli", aliases: ["broccoli"]),
        Definition(name: "Carrot", aliases: ["carrot"]),
        Definition(name: "Cheese", aliases: ["cheese"]),
        Definition(name: "Chicken", aliases: ["chicken"]),
        Definition(name: "Egg", aliases: ["egg", "eggs"]),
        Definition(name: "Fish", aliases: ["fish", "salmon", "tuna"]),
        Definition(name: "Garlic", aliases: ["garlic"]),
        Definition(name: "Lemon", aliases: ["lemon"]),
        Definition(name: "Mushroom", aliases: ["mushroom"]),
        Definition(name: "Onion", aliases: ["onion"]),
        Definition(name: "Orange", aliases: ["orange"]),
        Definition(name: "Pasta", aliases: ["pasta", "spaghetti", "macaroni"]),
        Definition(name: "Potato", aliases: ["potato"]),
        Definition(name: "Rice", aliases: ["rice"]),
        Definition(name: "Spinach", aliases: ["spinach"]),
        Definition(name: "Strawberry", aliases: ["strawberry"]),
        Definition(name: "Tomato", aliases: ["tomato"]),
        Definition(name: "Zucchini", aliases: ["zucchini", "courgette"])
    ]

    static func ingredients(from labels: [String]) -> [String] {
        var matches: [String] = []

        for label in labels {
            let words = label.lowercased().split { !$0.isLetter && !$0.isNumber }
            for definition in definitions {
                guard !matches.contains(definition.name) else { continue }
                if definition.aliases.contains(where: { alias in
                    let aliasWords = alias.split(separator: " ")
                    return words.containsSequence(aliasWords)
                }) {
                    matches.append(definition.name)
                }
            }
        }

        return matches
    }
}

private enum RecipeSuggestionGenerator {
    static func recipes(using ingredients: [String]) -> [Recipe] {
        let available = Set(ingredients)
        var suggestions: [Recipe] = []

        if available.contains("Egg"), available.contains("Tomato") {
            suggestions.append(Recipe(
                id: "vision-shakshuka",
                title: "Tomato and Egg Skillet",
                prepTime: "25 mins",
                detectedIngredients: ["Egg", "Tomato"].filter(available.contains),
                additionalPantryItemsNeeded: ["Olive Oil", "Salt", "Cumin"],
                steps: [
                    "Cook chopped tomatoes in a little olive oil until they soften.",
                    "Season with salt and cumin, then make small wells in the sauce.",
                    "Crack the eggs into the wells, cover, and cook until set."
                ]
            ))
        }

        if available.contains("Egg") {
            suggestions.append(Recipe(
                id: "vision-scramble",
                title: "Simple Egg Scramble",
                prepTime: "12 mins",
                detectedIngredients: ingredients.filter { ["Egg", "Spinach", "Tomato", "Cheese", "Onion"].contains($0) },
                additionalPantryItemsNeeded: ["Butter", "Salt", "Black Pepper"],
                steps: [
                    "Whisk the eggs with a pinch of salt and black pepper.",
                    "Melt butter in a pan and cook any detected vegetables until tender.",
                    "Add the eggs and stir gently over low heat until just set."
                ]
            ))
        }

        let vegetables = ingredients.filter {
            ["Bell Pepper", "Broccoli", "Carrot", "Mushroom", "Onion", "Spinach", "Tomato", "Zucchini"].contains($0)
        }
        if !vegetables.isEmpty {
            suggestions.append(Recipe(
                id: "vision-vegetable-skillet",
                title: "Seasonal Vegetable Skillet",
                prepTime: "20 mins",
                detectedIngredients: vegetables,
                additionalPantryItemsNeeded: ["Olive Oil", "Salt", "Black Pepper"],
                steps: [
                    "Cut the detected vegetables into bite-size pieces.",
                    "Heat olive oil in a skillet and cook the vegetables until tender.",
                    "Season with salt and black pepper, then serve warm."
                ]
            ))
        }

        if available.contains("Bread"), available.contains("Cheese") {
            suggestions.append(Recipe(
                id: "vision-grilled-cheese",
                title: "Grilled Cheese",
                prepTime: "10 mins",
                detectedIngredients: ["Bread", "Cheese"],
                additionalPantryItemsNeeded: ["Butter"],
                steps: [
                    "Place cheese between two slices of bread.",
                    "Butter the outside of the bread and cook in a pan over medium-low heat.",
                    "Turn once and cook until both sides are golden and the cheese has melted."
                ]
            ))
        }

        if !ingredients.filter({ ["Apple", "Banana", "Orange", "Strawberry"].contains($0) }).isEmpty {
            let fruits = ingredients.filter { ["Apple", "Banana", "Orange", "Strawberry"].contains($0) }
            suggestions.append(Recipe(
                id: "vision-fruit-bowl",
                title: "Fresh Fruit Bowl",
                prepTime: "10 mins",
                detectedIngredients: fruits,
                additionalPantryItemsNeeded: [],
                steps: [
                    "Wash and cut the detected fruit into bite-size pieces.",
                    "Combine in a bowl and serve chilled or at room temperature."
                ]
            ))
        }

        return Array(suggestions.prefix(2))
    }
}

private extension Array where Element == Substring {
    func containsSequence(_ sequence: [Substring]) -> Bool {
        guard !sequence.isEmpty, count >= sequence.count else { return false }
        return (0...(count - sequence.count)).contains { start in
            self[start..<(start + sequence.count)].elementsEqual(sequence)
        }
    }
}
