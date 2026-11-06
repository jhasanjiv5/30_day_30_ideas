import SwiftUI
import PassKit

public struct CostBreakdownView: View {
    @Binding public var room: Room
    @State private var selectedCategory: String = "All"
    @State private var showingApplePay: Bool = false
    
    public init(room: Binding<Room>) {
        self._room = room
    }
    
    var subtotal: Double {
        room.stagedItems.filter { $0.inPlan }.reduce(0) { $0 + $1.price }
    }
    
    var shipping: Double {
        subtotal > 1500 ? 0 : (subtotal > 0 ? 89 : 0)
    }
    
    var tax: Double {
        subtotal * 0.0825
    }
    
    var resaleCredit: Double {
        room.declutterItems.reduce(0) { $0 + ($1.potentialResaleValue ?? 0) }
    }
    
    var total: Double {
        max(0, subtotal + shipping + tax - resaleCredit)
    }
    
    public var body: some View {
        NavigationStack {
            List {
                // Summary Section
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("ESTIMATED ROOM MAKEOVER")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.secondary)
                        HStack {
                            Text("$\(Int(total))")
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                                .foregroundColor(.green)
                            Spacer()
                            Text("\(room.stagedItems.filter { $0.inPlan }.count) Items")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
                
                // Itemized Furniture & Decor List
                Section("Curated Additions & Decor") {
                    ForEach($room.stagedItems) { $item in
                        HStack(alignment: .top, spacing: 12) {
                            // Checkbox
                            Button(action: { item.inPlan.toggle() }) {
                                Image(systemName: item.inPlan ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(item.inPlan ? .blue : .secondary)
                                    .font(.system(size: 20))
                            }
                            .buttonStyle(.plain)
                            .padding(.top, 2)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(item.brand)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                    Text("·")
                                    Text(item.retailer)
                                        .font(.caption2)
                                        .foregroundColor(.blue)
                                }
                                Text(item.name)
                                    .font(.system(size: 14, weight: .semibold))
                                Text(item.reason)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(2)
                                
                                HStack {
                                    Text("$\(Int(item.price))")
                                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                                        .foregroundColor(.green)
                                    Spacer()
                                    if let url = URL(string: item.buyUrl) {
                                        Link("Buy on \(item.retailer)", destination: url)
                                            .font(.caption2.bold())
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 3)
                                            .background(Color.blue.opacity(0.12))
                                            .cornerRadius(6)
                                    }
                                }
                                .padding(.top, 4)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                
                // Financial Ledger
                Section("Estimated Cost Ledger") {
                    HStack {
                        Text("Subtotal")
                        Spacer()
                        Text("$\(Int(subtotal))").foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Estimated Shipping")
                        Spacer()
                        Text(shipping == 0 ? "FREE" : "$\(Int(shipping))").foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Estimated Sales Tax (8.25%)")
                        Spacer()
                        Text("$\(Int(tax))").foregroundColor(.secondary)
                    }
                    if resaleCredit > 0 {
                        HStack {
                            Text("Clutter Resale Credit")
                            Spacer()
                            Text("-$\(Int(resaleCredit))").foregroundColor(.green)
                        }
                    }
                }
            }
            .navigationTitle("Decor & Cost")
            .toolbar {
                ToolbarItem(placement: .bottomBar) {
                    Button(action: { showingApplePay = true }) {
                        HStack {
                            Text("Buy with")
                                .font(.footnote.bold())
                            Text("Pay")
                                .font(.headline.bold())
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.primary)
                        .foregroundColor(Color(uiColor: .systemBackground))
                        .cornerRadius(12)
                    }
                }
            }
        }
    }
}
