import SwiftUI

public struct ContentView: View {
    @State private var selectedTab = 1
    @StateObject private var reasoningModel = OnDeviceReasoningModel()
    
    // Sample Room State
    @State private var currentRoom = Room(
        id: "living-room-01",
        name: "Brooklyn Living Room",
        subtitle: "Warm Japandi transformation",
        category: .livingRoom,
        beforeImage: "https://images.unsplash.com/photo-1555041469-a586c61ea9bc?auto=format&fit=crop&w=1200&q=80",
        afterImage: "https://images.unsplash.com/photo-1600121848594-d8644e57abab?auto=format&fit=crop&w=1200&q=80",
        dimensions: RoomDimensions(widthFt: 14.5, lengthFt: 18.0, ceilingFt: 9.5, sqFt: 261),
        spaceRecoveredSqFt: 46.0,
        spaceRecoveredPercent: 17.6,
        declutterItems: [
            ClutterItem(
                id: "c1",
                label: "Laundry Mound on Sofa",
                category: "Clothing",
                boundingBox: .init(x: 35, y: 30, w: 30, h: 25),
                recommendation: "Transfer to lidded woven storage ottoman",
                spaceImpact: "Frees 3 primary sofa seats"
            ),
            ClutterItem(
                id: "c2",
                label: "Tangled TV & AV Cables",
                category: "Electronics",
                boundingBox: .init(x: 10, y: 70, w: 25, h: 20),
                recommendation: "Install J-channel cable raceway",
                spaceImpact: "Eliminates trip hazard and 80% wire noise"
            )
        ],
        stagedItems: [
            StagedItem(
                id: "f1",
                name: "Harmony Modular Sectional",
                brand: "West Elm",
                retailer: "West Elm",
                category: "Seating",
                price: 1899,
                currency: "USD",
                rating: 4.8,
                reviewCount: 312,
                dimensions: "106\"w x 67\"d x 33\"h",
                material: "Performance Linen",
                color: "Warm Ivory",
                buyUrl: "https://www.westelm.com",
                thumbnail: "https://images.unsplash.com/photo-1555041469-a586c61ea9bc?auto=format&fit=crop&w=400&q=80",
                spatialPosition: .init(x: 48, y: 56, depth3D: -1.2),
                reason: "Anchors seating without blocking northern window daylight line.",
                inPlan: true
            ),
            StagedItem(
                id: "f2",
                name: "LISABO Coffee Table",
                brand: "IKEA",
                retailer: "IKEA",
                category: "Table",
                price: 149,
                currency: "USD",
                rating: 4.7,
                reviewCount: 680,
                dimensions: "46.5\"l x 27.5\"w",
                material: "Ash Veneer",
                color: "Natural Ash",
                buyUrl: "https://www.ikea.com",
                thumbnail: "https://images.unsplash.com/photo-1533090161767-e6ffed986b88?auto=format&fit=crop&w=400&q=80",
                spatialPosition: .init(x: 60, y: 68, depth3D: -0.6),
                reason: "Bevelled edges improve traffic flow clearance.",
                inPlan: true
            )
        ],
        enhancementMetrics: EnhancementMetrics(
            luxImprovement: "+34% Ambient Daylight",
            colorTone: "Warm Ochre & Ivory (3100K)",
            clutterReduction: 86,
            acousticsNote: "Textured wool loop rug dampens hardwood floor echo"
        ),
        reasoningSteps: [
            ReasoningStep(step: 1, title: "LiDAR Depth Extraction", detail: "Calculated room volume 2,479 cu.ft.", durationMs: 42, status: "completed")
        ]
    )
    
    public init() {}
    
    public var body: some View {
        TabView(selection: $selectedTab) {
            CameraViewfinder(room: $currentRoom) { image in
                Task {
                    _ = await reasoningModel.analyzeRoomFootage(image: image)
                    selectedTab = 1
                }
            }
            .tabItem {
                Label("Capture", systemImage: "camera")
            }
            .tag(0)
            
            ThreeDPerspectiveView(room: $currentRoom)
                .tabItem {
                    Label("3D Space", systemImage: "cube.transparent")
                }
                .tag(1)
            
            DeclutterView(room: $currentRoom)
                .tabItem {
                    Label("Declutter", systemImage: "square.stack.3d.down.right")
                }
                .tag(2)
            
            CostBreakdownView(room: $currentRoom)
                .tabItem {
                    Label("Cost & Decor", systemImage: "cart")
                }
                .tag(3)
        }
        .tint(.purple)
    }
}
