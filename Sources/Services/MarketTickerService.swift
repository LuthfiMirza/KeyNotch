import Cocoa
import SwiftUI
import Combine

public struct MarketItem: Identifiable, Codable, Equatable {
    public let id: String
    public let name: String
    public let symbol: String
    public var priceString: String
    public var changePercent: Double
    public let category: String
    public var lastUpdated: Date
    
    public var isPositive: Bool {
        changePercent >= 0
    }
    
    public var changeString: String {
        let prefix = changePercent >= 0 ? "+" : ""
        return String(format: "%@%.2f%%", prefix, changePercent)
    }
    
    public init(id: String, name: String, symbol: String, priceString: String, changePercent: Double, category: String, lastUpdated: Date = Date()) {
        self.id = id
        self.name = name
        self.symbol = symbol
        self.priceString = priceString
        self.changePercent = changePercent
        self.category = category
        self.lastUpdated = lastUpdated
    }
}

public final class MarketTickerService: ObservableObject {
    public static let shared = MarketTickerService()
    
    @Published public var items: [MarketItem] = []
    @Published public var isFetching: Bool = false
    @Published public var lastUpdatedString: String = "Just now"
    
    @Published public var pinnedTickerId: String {
        didSet {
            UserDefaults.standard.set(pinnedTickerId, forKey: "pinnedTickerId")
        }
    }
    
    @Published public var showTickerInCompactNotch: Bool {
        didSet {
            UserDefaults.standard.set(showTickerInCompactNotch, forKey: "showTickerInCompactNotch")
        }
    }
    
    public var pinnedItem: MarketItem? {
        items.first(where: { $0.id == pinnedTickerId }) ?? items.first
    }
    
    private var lastFetchTime: Date?
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        self.pinnedTickerId = UserDefaults.standard.string(forKey: "pinnedTickerId") ?? "USD/IDR"
        self.showTickerInCompactNotch = UserDefaults.standard.bool(forKey: "showTickerInCompactNotch")
        
        loadInitialData()
        
        // Auto-refresh when expanded if stale (> 5 minutes)
        IslandState.shared.$isExpanded
            .receive(on: RunLoop.main)
            .sink { [weak self] expanded in
                guard let self = self else { return }
                if expanded {
                    if let last = self.lastFetchTime {
                        if Date().timeIntervalSince(last) > 300 {
                            self.fetchLatestQuotes()
                        }
                    } else {
                        self.fetchLatestQuotes()
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    private func loadInitialData() {
        items = [
            MarketItem(id: "USD/IDR", name: "USD to Rupiah", symbol: "USD/IDR", priceString: "Rp 18.148", changePercent: 0.12, category: "Forex"),
            MarketItem(id: "BTC", name: "Bitcoin", symbol: "BTC/USD", priceString: "$79,591", changePercent: -1.07, category: "Crypto"),
            MarketItem(id: "ETH", name: "Ethereum", symbol: "ETH/USD", priceString: "$2,308", changePercent: -1.02, category: "Crypto"),
            MarketItem(id: "BBCA", name: "Bank Central Asia", symbol: "BBCA.JK", priceString: "Rp 4.900", changePercent: 0.80, category: "Stocks"),
            MarketItem(id: "AAPL", name: "Apple Inc.", symbol: "AAPL", priceString: "$343.91", changePercent: 1.15, category: "Stocks"),
            MarketItem(id: "NVDA", name: "Nvidia Corp.", symbol: "NVDA", priceString: "$138.25", changePercent: 2.40, category: "Stocks")
        ]
    }
    
    public func toggleShowTickerInNotch() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            showTickerInCompactNotch.toggle()
        }
        
        let ticker = pinnedItem?.symbol ?? "USD/IDR"
        IslandState.shared.triggerHUD(
            HUDPayload(
                type: .custom,
                title: showTickerInCompactNotch ? "Market Ticker ON" : "Market Ticker OFF",
                subtitle: showTickerInCompactNotch ? "Showing \(ticker) in compact notch" : "Clock & media standard view",
                iconName: showTickerInCompactNotch ? "chart.line.uptrend.xyaxis" : "chart.line.flattrend.xyaxis",
                isSuccess: showTickerInCompactNotch
            ),
            duration: 1.2
        )
    }
    
    public func pinTicker(_ id: String) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            pinnedTickerId = id
        }
        
        if let item = items.first(where: { $0.id == id }) {
            IslandState.shared.triggerHUD(
                HUDPayload(
                    type: .custom,
                    title: "Pinned to Notch",
                    subtitle: "\(item.symbol): \(item.priceString) (\(item.changeString))",
                    iconName: "pin.fill",
                    isSuccess: true
                ),
                duration: 1.2
            )
        }
    }
    
    // MARK: - Live Quote Fetchers
    
    public func fetchLatestQuotes() {
        guard !isFetching else { return }
        isFetching = true
        
        let group = DispatchGroup()
        
        // 1. Fetch Forex (USD/IDR)
        group.enter()
        fetchUSDIDR { [weak self] rate in
            if let rate = rate {
                DispatchQueue.main.async {
                    if let idx = self?.items.firstIndex(where: { $0.id == "USD/IDR" }) {
                        let formatted = String(format: "Rp %.0f", rate)
                        self?.items[idx].priceString = formatted
                        self?.items[idx].lastUpdated = Date()
                    }
                }
            }
            group.leave()
        }
        
        // 2. Fetch Crypto (BTC, ETH)
        group.enter()
        fetchCryptoRates { [weak self] cryptoData in
            if let data = cryptoData {
                DispatchQueue.main.async {
                    if let btc = data["bitcoin"] {
                        if let idx = self?.items.firstIndex(where: { $0.id == "BTC" }) {
                            self?.items[idx].priceString = String(format: "$%.0f", btc.usd)
                            self?.items[idx].changePercent = btc.change
                            self?.items[idx].lastUpdated = Date()
                        }
                    }
                    if let eth = data["ethereum"] {
                        if let idx = self?.items.firstIndex(where: { $0.id == "ETH" }) {
                            self?.items[idx].priceString = String(format: "$%.2f", eth.usd)
                            self?.items[idx].changePercent = eth.change
                            self?.items[idx].lastUpdated = Date()
                        }
                    }
                }
            }
            group.leave()
        }
        
        // 3. Fetch Stock (BBCA.JK)
        group.enter()
        fetchYahooStock(symbol: "BBCA.JK") { [weak self] result in
            if let (price, change) = result {
                DispatchQueue.main.async {
                    if let idx = self?.items.firstIndex(where: { $0.id == "BBCA" }) {
                        self?.items[idx].priceString = String(format: "Rp %.0f", price)
                        self?.items[idx].changePercent = change
                        self?.items[idx].lastUpdated = Date()
                    }
                }
            }
            group.leave()
        }
        
        // 4. Fetch Stock (AAPL)
        group.enter()
        fetchYahooStock(symbol: "AAPL") { [weak self] result in
            if let (price, change) = result {
                DispatchQueue.main.async {
                    if let idx = self?.items.firstIndex(where: { $0.id == "AAPL" }) {
                        self?.items[idx].priceString = String(format: "$%.2f", price)
                        self?.items[idx].changePercent = change
                        self?.items[idx].lastUpdated = Date()
                    }
                }
            }
            group.leave()
        }
        
        group.notify(queue: .main) { [weak self] in
            guard let self = self else { return }
            self.isFetching = false
            self.lastFetchTime = Date()
            
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm"
            self.lastUpdatedString = "Updated \(formatter.string(from: Date()))"
        }
    }
    
    private func fetchUSDIDR(completion: @escaping (Double?) -> Void) {
        guard let url = URL(string: "https://open.er-api.com/v6/latest/USD") else {
            completion(nil)
            return
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 4.0
        
        URLSession.shared.dataTask(with: request) { data, _, _ in
            guard let data = data else {
                completion(nil)
                return
            }
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let rates = json["rates"] as? [String: Any],
                   let idrRate = rates["IDR"] as? Double {
                    completion(idrRate)
                    return
                }
            } catch {}
            completion(nil)
        }.resume()
    }
    
    private func fetchCryptoRates(completion: @escaping ([String: (usd: Double, change: Double)]?) -> Void) {
        guard let url = URL(string: "https://api.coingecko.com/api/v3/simple/price?ids=bitcoin,ethereum&vs_currencies=usd&include_24hr_change=true") else {
            completion(nil)
            return
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 4.0
        
        URLSession.shared.dataTask(with: request) { data, _, _ in
            guard let data = data else {
                completion(nil)
                return
            }
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: [String: Any]] {
                    var result: [String: (usd: Double, change: Double)] = [:]
                    
                    if let btc = json["bitcoin"],
                       let usd = btc["usd"] as? Double {
                        let change = btc["usd_24h_change"] as? Double ?? 0.0
                        result["bitcoin"] = (usd: usd, change: change)
                    }
                    if let eth = json["ethereum"],
                       let usd = eth["usd"] as? Double {
                        let change = eth["usd_24h_change"] as? Double ?? 0.0
                        result["ethereum"] = (usd: usd, change: change)
                    }
                    completion(result)
                    return
                }
            } catch {}
            completion(nil)
        }.resume()
    }
    
    private func fetchYahooStock(symbol: String, completion: @escaping ((price: Double, changePercent: Double)?) -> Void) {
        guard let url = URL(string: "https://query1.finance.yahoo.com/v8/finance/chart/\(symbol)?interval=1d&range=1d") else {
            completion(nil)
            return
        }
        
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 4.0
        
        URLSession.shared.dataTask(with: request) { data, _, _ in
            guard let data = data else {
                completion(nil)
                return
            }
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let chart = json["chart"] as? [String: Any],
                   let resultList = chart["result"] as? [[String: Any]],
                   let first = resultList.first,
                   let meta = first["meta"] as? [String: Any],
                   let regularPrice = meta["regularMarketPrice"] as? Double {
                    
                    let prevClose = meta["chartPreviousClose"] as? Double ?? regularPrice
                    let changePercent = prevClose > 0 ? ((regularPrice - prevClose) / prevClose) * 100.0 : 0.0
                    completion((price: regularPrice, changePercent: changePercent))
                    return
                }
            } catch {}
            completion(nil)
        }.resume()
    }
}
