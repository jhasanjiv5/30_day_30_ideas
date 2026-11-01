//
//  RecipeViewModel.swift
//  CookLens
//

import SwiftUI

@MainActor
@Observable
final class RecipeViewModel {
    enum State: Equatable {
        case idle
        case capturing
        case analyzing
        case success([Recipe])
        case error(String)

        static func == (lhs: State, rhs: State) -> Bool {
            switch (lhs, rhs) {
            case (.idle, .idle), (.capturing, .capturing), (.analyzing, .analyzing):
                return true
            case (.success(let a), .success(let b)):
                return a.map(\.id) == b.map(\.id)
            case (.error(let a), .error(let b)):
                return a == b
            default:
                return false
            }
        }
    }

    var state: State = .idle
    var selectedImage: UIImage?
    
    private let modelService: IngredientRecipeServiceProtocol
    let cameraManager = CameraManager()

    init(modelService: IngredientRecipeServiceProtocol = LocalVisionInferenceService()) {
        self.modelService = modelService
    }

    func scanAndSuggest() {
        Task { @MainActor in
            state = .capturing
            guard let image = await cameraManager.capturePhoto() else {
                state = .error("Failed to capture image from camera.")
                return
            }
            
            self.selectedImage = image
            self.state = .analyzing
            
            do {
                let recipes = try await modelService.analyzeIngredientsAndGenerateRecipes(from: image)
                self.state = .success(recipes)
            } catch {
                self.state = .error(error.localizedDescription)
            }
        }
    }
    
    func reset() {
        selectedImage = nil
        state = .idle
    }
}
