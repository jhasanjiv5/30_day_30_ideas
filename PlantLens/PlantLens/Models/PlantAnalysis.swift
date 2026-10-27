import Foundation

struct PlantAnalysis: Codable, Identifiable {
    var id: String { plantName }
    
    let isPlant: Bool
    let plantName: String
    let healthPercentage: Int
    let briefStatus: String
    let diagnosis: String
    let wateringNeeds: String
    let sunlightNeeds: String
    let immediateCareSteps: [String]
    let longTermAdvice: String

    static let fallbackNotPlant = PlantAnalysis(
        isPlant: false,
        plantName: "Not a Plant",
        healthPercentage: 0,
        briefStatus: "No recognizable plant detected in frame. Try pointing directly at the leaves or stem.",
        diagnosis: "Unable to find botanical characteristics.",
        wateringNeeds: "N/A",
        sunlightNeeds: "N/A",
        immediateCareSteps: ["Ensure the plant is well-lit", "Center the leaf in the reticle"],
        longTermAdvice: "N/A"
    )
}