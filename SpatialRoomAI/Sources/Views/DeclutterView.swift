import SwiftUI

public struct DeclutterView: View {
    @Binding public var room: Room
    
    public init(room: Binding<Room>) {
        self._room = room
    }
    
    var clearedCount: Int {
        room.declutterItems.filter { $0.isCleared }.count
    }
    
    var progress: Double {
        Double(clearedCount) / Double(max(1, room.declutterItems.count))
    }
    
    public var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            VStack(alignment: .leading) {
                                Text("SPACE RECOVERED")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.secondary)
                                Text("+\(Int(room.spaceRecoveredSqFt)) sq ft")
                                    .font(.system(size: 28, weight: .bold, design: .rounded))
                                    .foregroundColor(.green)
                            }
                            Spacer()
                            Text("\(Int(progress * 100))% Complete")
                                .font(.subheadline.bold())
                                .foregroundColor(.green)
                        }
                        
                        ProgressView(value: progress)
                            .tint(.green)
                    }
                    .padding(.vertical, 4)
                }
                
                Section("Identified Clutter Vectors") {
                    ForEach($room.declutterItems) { $item in
                        HStack(alignment: .top, spacing: 12) {
                            Button(action: { item.isCleared.toggle() }) {
                                Image(systemName: item.isCleared ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(item.isCleared ? .green : .secondary)
                                    .font(.system(size: 22))
                            }
                            .buttonStyle(.plain)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(item.label)
                                        .font(.system(size: 15, weight: .semibold))
                                        .strikethrough(item.isCleared)
                                    Spacer()
                                    Text(item.category)
                                        .font(.caption2)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.red.opacity(0.12))
                                        .foregroundColor(.red)
                                        .cornerRadius(4)
                                }
                                
                                Text(item.recommendation)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Text(item.spaceImpact)
                                    .font(.caption2.bold())
                                    .foregroundColor(.green)
                                    .padding(.top, 2)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("Declutter")
        }
    }
}
