import Foundation
import Testing
@testable import EnsembleCore

@Suite("GroupRanker Tests")
struct GroupRankerTests {

    @Test("Computes 0.6 * mean + 0.4 * min blend accurately")
    func testMeanMinBlend() {
        let actionItem = MediaItem(
            id: "action-1",
            title: "Pure Action",
            synopsis: "Explosive chase.",
            year: 2025,
            genres: ["Action"],
            moodTags: ["kinetic"],
            runtimeMinutes: 90,
            ageRating: .pg13,
            posterKey: "action-1"
        )

        let dramaItem = MediaItem(
            id: "drama-1",
            title: "Balanced Action Drama",
            synopsis: "Thoughtful thriller.",
            year: 2025,
            genres: ["Action", "Drama"],
            moodTags: ["kinetic", "emotional"],
            runtimeMinutes: 95,
            ageRating: .pg13,
            posterKey: "drama-1"
        )

        let maya = RoomParticipant(
            id: UUID(),
            displayName: "Maya",
            avatarSymbol: "bolt.circle.fill",
            accentHex: "#2563EB",
            isChild: false,
            tasteVector: TasteVector(genreWeights: ["action": 1.0], moodWeights: ["kinetic": 1.0])
        )
        let david = RoomParticipant(
            id: UUID(),
            displayName: "David",
            avatarSymbol: "theatermasks.circle.fill",
            accentHex: "#0F766E",
            isChild: false,
            tasteVector: TasteVector(genreWeights: ["drama": 1.0], moodWeights: ["emotional": 1.0])
        )

        let ranker = GroupRanker()
        let results = ranker.rank(catalogue: [actionItem, dramaItem], participants: [maya, david])

        // Balanced Action Drama satisfies both Maya and David, avoiding least-misery penalty (min = 0)
        #expect(results.first?.item.id == "drama-1")

        let expectedActionMean = (maya.tasteVector.affinity(for: actionItem) + david.tasteVector.affinity(for: actionItem)) / 2.0
        let expectedActionMin = min(maya.tasteVector.affinity(for: actionItem), david.tasteVector.affinity(for: actionItem))
        let actionResult = results.first(where: { $0.item.id == "action-1" })!

        #expect(abs(actionResult.score - (0.6 * expectedActionMean + 0.4 * expectedActionMin)) < 0.0001)
    }

    @Test("Child joining enforces G/PG filter; child leaving restores PG-13/R items")
    func testChildAgeFilterJoinAndLeave() throws {
        let catalogue = try CatalogueLoader.loadBundledCatalogue()
        let personas = try PersonaLoader.loadBundledPersonas()

        let mayaPersona = try #require(personas.first(where: { $0.id == "maya-action" }))
        let miaPersona = try #require(personas.first(where: { $0.id == "mia-child" }))

        let maya = RoomParticipant(
            id: UUID(),
            displayName: mayaPersona.displayName,
            avatarSymbol: mayaPersona.avatarSymbol,
            accentHex: mayaPersona.accentHex,
            isChild: false,
            tasteVector: TasteVectorBuilder.compute(from: mayaPersona.watchHistory)
        )
        let mia = RoomParticipant(
            id: UUID(),
            displayName: miaPersona.displayName,
            avatarSymbol: miaPersona.avatarSymbol,
            accentHex: miaPersona.accentHex,
            isChild: true,
            tasteVector: TasteVectorBuilder.compute(from: miaPersona.watchHistory)
        )

        let ranker = GroupRanker(limit: 24)

        // Child present -> zero PG-13 or R items
        let withChild = ranker.rank(catalogue: catalogue, participants: [maya, mia])
        #expect(!withChild.isEmpty)
        #expect(withChild.allSatisfy { $0.item.ageRating <= .pg })

        // Child leaves -> PG-13 and R items return
        let withoutChild = ranker.rank(catalogue: catalogue, participants: [maya])
        #expect(withoutChild.contains(where: { $0.item.ageRating >= .pg13 }))
    }

    @Test("Runtime budget filter and top-10 cap work with natural language query")
    func testRuntimeFilterAndWhyCaption() throws {
        let catalogue = try CatalogueLoader.loadBundledCatalogue()
        let personas = try PersonaLoader.loadBundledPersonas()
        let maya = personas[0]
        let participant = RoomParticipant(
            id: UUID(),
            displayName: maya.displayName,
            avatarSymbol: maya.avatarSymbol,
            accentHex: maya.accentHex,
            isChild: false,
            tasteVector: TasteVectorBuilder.compute(from: maya.watchHistory)
        )

        let intent = NaturalQueryParser.parse("something for all of us under 40 min")
        #expect(intent.maxRuntimeMinutes == 40)
        #expect(intent.isSceneQuery == false)

        let ranker = GroupRanker(limit: 10)
        let results = ranker.rank(
            catalogue: catalogue,
            participants: [participant],
            maxRuntimeMinutes: intent.maxRuntimeMinutes
        )

        #expect(results.count <= 10)
        #expect(!results.isEmpty)
        #expect(results.allSatisfy { $0.item.runtimeMinutes <= 40 })
        #expect(results.allSatisfy { $0.whyCaption.contains("Maya") })
    }

    @Test("Filters catalogue to media playable on installed TV apps and resolves deep-link provider")
    func testInstalledTVAppsFilter() throws {
        let catalogue = try CatalogueLoader.loadBundledCatalogue()
        let personas = try PersonaLoader.loadBundledPersonas()
        let maya = personas[0]
        let participant = RoomParticipant(
            id: UUID(),
            displayName: maya.displayName,
            avatarSymbol: maya.avatarSymbol,
            accentHex: maya.accentHex,
            isChild: false,
            tasteVector: TasteVectorBuilder.compute(from: maya.watchHistory)
        )

        let installedOnlyDisney: Set<StreamingAppID> = [.disneyPlus]
        let results = GroupRanker(limit: 24).rank(
            catalogue: catalogue,
            participants: [participant],
            installedAppIDs: installedOnlyDisney
        )

        #expect(!results.isEmpty)
        #expect(results.allSatisfy { ranked in
            ranked.item.providers.contains(where: { $0.appID == .disneyPlus })
        })
        let firstProvider = results.first?.item.preferredProvider(installedApps: installedOnlyDisney)
        #expect(firstProvider?.appID == .disneyPlus)
        #expect(firstProvider?.deepLinkURL.hasPrefix("disneyplus://") == true)
    }
}
