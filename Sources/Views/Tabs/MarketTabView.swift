import SwiftUI

public struct MarketTabView: View {
    @ObservedObject var market = MarketTickerService.shared
    @State private var selectedCategory: String = "All"
    
    private let categories = ["All", "Forex", "Crypto", "Stocks"]
    
    public init() {}
    
    private var filteredItems: [MarketItem] {
        if selectedCategory == "All" {
            return market.items
        }
        return market.items.filter { $0.category == selectedCategory }
    }
    
    public var body: some View {
        VStack(spacing: 8) {
            // MARK: - Header: Filters & Refresh
            HStack(spacing: 6) {
                // Category Pills
                ForEach(categories, id: \.self) { cat in
                    Button(action: {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                            selectedCategory = cat
                        }
                    }) {
                        Text(cat)
                            .font(.system(size: 10, weight: selectedCategory == cat ? .bold : .medium))
                            .foregroundColor(selectedCategory == cat ? .white : .white.opacity(0.5))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(selectedCategory == cat ? Color.white.opacity(0.16) : Color.white.opacity(0.05))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
                Spacer()
                
                // Status / Last Updated
                Text(market.lastUpdatedString)
                    .font(.system(size: 9))
                    .foregroundColor(.white.opacity(0.45))
                
                // 1-Click Refresh
                Button(action: {
                    market.fetchLatestQuotes()
                }) {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.08))
                            .frame(width: 22, height: 22)
                        
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white.opacity(0.8))
                            .rotationEffect(.degrees(market.isFetching ? 360 : 0))
                            .animation(market.isFetching ? Animation.linear(duration: 0.8).repeatForever(autoreverses: false) : .default, value: market.isFetching)
                    }
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 14)
            .padding(.top, 2)
            
            // MARK: - 2-Column Market Grid
            let columns = [
                GridItem(.flexible(), spacing: 8),
                GridItem(.flexible(), spacing: 8)
            ]
            
            ScrollView(.vertical, showsIndicators: false) {
                LazyVGrid(columns: columns, spacing: 6) {
                    ForEach(filteredItems) { item in
                        marketCard(for: item)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 4)
            }
            .frame(height: 122)
            
            // MARK: - Footer: Pinned Ticker Status & Notch Toggle
            HStack(spacing: 8) {
                HStack(spacing: 4) {
                    Image(systemName: "pin.fill")
                        .font(.system(size: 8))
                        .foregroundColor(.yellow)
                    Text("Notch Ticker:")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                    Text(market.pinnedItem?.symbol ?? "USD/IDR")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(.yellow)
                }
                
                Spacer()
                
                Button(action: {
                    market.toggleShowTickerInNotch()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: market.showTickerInCompactNotch ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(market.showTickerInCompactNotch ? .green : .white.opacity(0.4))
                        Text(market.showTickerInCompactNotch ? "Show in Notch: ON" : "Show in Notch: OFF")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(.white.opacity(0.85))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3.5)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Capsule())
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 14)
            .padding(.top, 2)
        }
    }
    
    // MARK: - Market Card Component
    
    private func marketCard(for item: MarketItem) -> some View {
        let isPinned = market.pinnedTickerId == item.id
        
        return HStack(spacing: 8) {
            // Category Icon Badge
            ZStack {
                Circle()
                    .fill(badgeColor(for: item.category).opacity(0.18))
                    .frame(width: 26, height: 26)
                
                Image(systemName: iconName(for: item.category, symbol: item.id))
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(badgeColor(for: item.category))
            }
            
            // Symbol & Name
            VStack(alignment: .leading, spacing: 1) {
                Text(item.symbol)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Text(item.name)
                    .font(.system(size: 9))
                    .foregroundColor(.white.opacity(0.5))
                    .lineLimit(1)
            }
            
            Spacer(minLength: 4)
            
            // Price & Change Badge
            VStack(alignment: .trailing, spacing: 2) {
                Text(item.priceString)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                
                Text(item.changeString)
                    .font(.system(size: 8.5, weight: .bold, design: .rounded))
                    .foregroundColor(item.isPositive ? Color.green : Color.red)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1.5)
                    .background((item.isPositive ? Color.green : Color.red).opacity(0.18))
                    .clipShape(Capsule())
            }
            
            // Pin to Notch Button
            Button(action: {
                market.pinTicker(item.id)
            }) {
                Image(systemName: isPinned ? "pin.fill" : "pin")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(isPinned ? .yellow : .white.opacity(0.25))
                    .frame(width: 16, height: 16)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isPinned ? Color.yellow.opacity(0.08) : Color.white.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(isPinned ? Color.yellow.opacity(0.3) : Color.white.opacity(0.06), lineWidth: 0.5)
        )
    }
    
    private func iconName(for category: String, symbol: String) -> String {
        switch category {
        case "Forex": return "dollarsign.circle.fill"
        case "Crypto": return "bitcoinsign.circle.fill"
        case "Stocks":
            if symbol == "AAPL" { return "applelogo" }
            if symbol == "NVDA" { return "cpu" }
            return "chart.bar.xaxis"
        default: return "chart.line.uptrend.xyaxis"
        }
    }
    
    private func badgeColor(for category: String) -> Color {
        switch category {
        case "Forex": return .green
        case "Crypto": return .orange
        case "Stocks": return .cyan
        default: return .white
        }
    }
}
