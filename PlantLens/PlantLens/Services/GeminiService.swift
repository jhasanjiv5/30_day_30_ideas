import UIKit

enum NetworkError: LocalizedError {
    case invalidImage
    case apiError(String)
    case parseError
    
    var errorDescription: String? {
        switch self {
        case .invalidImage: return "Failed to process photo."
        case .apiError(let msg): return msg
        case .parseError: return "Could not parse plant analysis."
        }
    }
}

final class GeminiService {
    static let shared = GeminiService()
    
    // Store your key in Secrets.plist or replace directly for testing
    private var apiKey: String {
        guard let path = Bundle.main.path(forResource: "Secrets", ofType: "plist"),
              let dict = NSDictionary(contentsOfFile: path) as? [String: AnyObject],
              let key = dict["GEMINI_API_KEY"] as? String, !key.isEmpty else {
            return "YOUR_GEMINI_API_KEY" // Fallback during local dev
        }
        return key
    }
    
    func analyze(image: UIImage) async throws -> PlantAnalysis {
        guard let jpegData = image.jpegData(compressionQuality: 0.6) else {
            throw NetworkError.invalidImage
        }
        
        let base64String = jpegData.base64EncodedString()
        let endpoint = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=\(apiKey)"
        
        guard let url = URL(string: endpoint) else {
            throw NetworkError.apiError("Invalid API endpoint.")
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let systemPrompt = """
        You are an expert plant pathologist. Inspect the image. 
        If it is NOT a plant, set "isPlant": false and fill other fields with "N/A".
        If it IS a plant, provide:
        - "plantName": Common and scientific name
        - "healthPercentage": Integer score from 0 to 100
        - "briefStatus": 1-2 sentence assessment
        - "diagnosis": Detailed explanation of symptoms, discoloration, or pests
        - "wateringNeeds": Exact hydration requirement
        - "sunlightNeeds": Lighting guidelines
        - "immediateCareSteps": Array of 2-4 actionable bullet points
        - "longTermAdvice": Long term maintenance
        
        Return ONLY valid JSON matching this schema:
        {
          "isPlant": true,
          "plantName": "String",
          "healthPercentage": 90,
          "briefStatus": "String",
          "diagnosis": "String",
          "wateringNeeds": "String",
          "sunlightNeeds": "String",
          "immediateCareSteps": ["String"],
          "longTermAdvice": "String"
        }
        """
        
        let payload: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        ["text": systemPrompt],
                        [
                            "inline_data": [
                                "mime_type": "image/jpeg",
                                "data": base64String
                            ]
                        ]
                    ]
                ]
            ],
            "generationConfig": [
                "response_mime_type": "application/json",
                "temperature": 0.2
            ]
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw NetworkError.apiError("Gemini server error. Check API key and quota.")
        }
        
        let geminiResponse = try JSONDecoder().decode(GeminiRawResponse.self, data: data)
        guard let rawJSONText = geminiResponse.candidates.first?.content.parts.first?.text,
              let cleanData = rawJSONText.data(using: .utf8) else {
            throw NetworkError.parseError
        }
        
        return try JSONDecoder().decode(PlantAnalysis.self, data: cleanData)
    }
}

// Internal Gemini Response models
struct GeminiRawResponse: Codable {
    let candidates: [Candidate]
    struct Candidate: Codable {
        let content: Content
    }
    struct Content: Codable {
        let parts: [Part]
    }
    struct Part: Codable {
        let text: String
    }
}