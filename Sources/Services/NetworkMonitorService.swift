import Cocoa
import SwiftUI
import Darwin
import Combine

public enum PingQuality {
    case excellent // < 40ms (green)
    case good      // 40 - 90ms (light green / teal)
    case fair      // 90 - 160ms (yellow)
    case poor      // > 160ms (red)
    case unknown   // timeout or disconnected
    
    public var colorName: String {
        switch self {
        case .excellent, .good: return "green"
        case .fair: return "yellow"
        case .poor: return "red"
        case .unknown: return "gray"
        }
    }
}

public final class NetworkMonitorService: ObservableObject {
    public static let shared = NetworkMonitorService()
    
    @Published public var downloadSpeedBytesPerSec: Double = 0.0
    @Published public var uploadSpeedBytesPerSec: Double = 0.0
    @Published public var downloadSpeedString: String = "0 KB/s"
    @Published public var uploadSpeedString: String = "0 KB/s"
    @Published public var pingMs: Double? = nil
    @Published public var pingString: String = "-- ms"
    @Published public var pingQuality: PingQuality = .unknown
    
    @Published public var showInCompactNotch: Bool {
        didSet {
            UserDefaults.standard.set(showInCompactNotch, forKey: "showNetworkInCompactNotch")
            evaluateMonitoringState()
        }
    }
    
    private var prevBytes: (inBytes: UInt64, outBytes: UInt64, time: CFAbsoluteTime)?
    private var monitorTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    private let queue = DispatchQueue(label: "com.keynotch.networkmonitor", qos: .utility)
    
    private init() {
        self.showInCompactNotch = UserDefaults.standard.bool(forKey: "showNetworkInCompactNotch")
        
        // Zero-CPU optimization: Only monitor when Island is expanded OR when user enabled compact view
        IslandState.shared.$isExpanded
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.evaluateMonitoringState()
            }
            .store(in: &cancellables)
    }
    
    public func toggleShowInCompactNotch() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            showInCompactNotch.toggle()
        }
        
        IslandState.shared.triggerHUD(
            HUDPayload(
                type: .custom,
                title: showInCompactNotch ? "Network Pill in Notch ON" : "Network Pill in Notch OFF",
                subtitle: showInCompactNotch ? "Live speed displayed in compact notch" : "Clock & media standard view",
                iconName: showInCompactNotch ? "network" : "network.slash",
                isSuccess: showInCompactNotch
            ),
            duration: 1.2
        )
    }
    
    private func evaluateMonitoringState() {
        let shouldMonitor = IslandState.shared.isExpanded || showInCompactNotch
        if shouldMonitor {
            startMonitoring()
        } else {
            stopMonitoring()
        }
    }
    
    public func startMonitoring() {
        guard monitorTimer == nil else { return }
        
        // Take initial baseline
        prevBytes = (inBytes: getActiveNetworkBytes().inBytes, outBytes: getActiveNetworkBytes().outBytes, time: CFAbsoluteTimeGetCurrent())
        sampleNetwork()
        
        // 1.5-second interval while active
        monitorTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            self?.sampleNetwork()
        }
    }
    
    public func stopMonitoring() {
        monitorTimer?.invalidate()
        monitorTimer = nil
        prevBytes = nil
        
        DispatchQueue.main.async {
            self.downloadSpeedBytesPerSec = 0.0
            self.uploadSpeedBytesPerSec = 0.0
            self.downloadSpeedString = "0 KB/s"
            self.uploadSpeedString = "0 KB/s"
        }
    }
    
    public func sampleNetwork() {
        queue.async { [weak self] in
            guard let self = self else { return }
            
            let currentTime = CFAbsoluteTimeGetCurrent()
            let currentBytes = self.getActiveNetworkBytes()
            
            var downSpeed: Double = 0.0
            var upSpeed: Double = 0.0
            
            if let prev = self.prevBytes {
                let deltaTime = currentTime - prev.time
                if deltaTime > 0.4 {
                    // Handle 32-bit counter wrap-around
                    let deltaIn: UInt64
                    if currentBytes.inBytes >= prev.inBytes {
                        deltaIn = currentBytes.inBytes - prev.inBytes
                    } else {
                        deltaIn = (UInt64(UInt32.max) - prev.inBytes) + currentBytes.inBytes
                    }
                    
                    let deltaOut: UInt64
                    if currentBytes.outBytes >= prev.outBytes {
                        deltaOut = currentBytes.outBytes - prev.outBytes
                    } else {
                        deltaOut = (UInt64(UInt32.max) - prev.outBytes) + currentBytes.outBytes
                    }
                    
                    downSpeed = Double(deltaIn) / deltaTime
                    upSpeed = Double(deltaOut) / deltaTime
                }
            }
            
            self.prevBytes = (inBytes: currentBytes.inBytes, outBytes: currentBytes.outBytes, time: currentTime)
            
            // Measure Ping Latency
            let ping = self.measureTCPPing(host: "1.1.1.1", port: 53) ?? self.measureTCPPing(host: "8.8.8.8", port: 53)
            
            let downStr = self.formatSpeed(downSpeed)
            let upStr = self.formatSpeed(upSpeed)
            let quality = self.evaluateQuality(ping)
            let pingStr = ping != nil ? String(format: "%.0f ms", ping!) : "-- ms"
            
            DispatchQueue.main.async {
                self.downloadSpeedBytesPerSec = downSpeed
                self.uploadSpeedBytesPerSec = upSpeed
                self.downloadSpeedString = downStr
                self.uploadSpeedString = upStr
                self.pingMs = ping
                self.pingString = pingStr
                self.pingQuality = quality
            }
        }
    }
    
    // MARK: - BSD Socket Network Bytes Fetcher
    
    private func getActiveNetworkBytes() -> (inBytes: UInt64, outBytes: UInt64) {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else {
            return (0, 0)
        }
        defer { freeifaddrs(ifaddr) }
        
        var totalIn: UInt64 = 0
        var totalOut: UInt64 = 0
        var ptr: UnsafeMutablePointer<ifaddrs>? = firstAddr
        
        while let p = ptr {
            let name = String(cString: p.pointee.ifa_name)
            let flags = Int32(p.pointee.ifa_flags)
            let family = p.pointee.ifa_addr.pointee.sa_family
            
            // Filter: Active, running non-loopback network interface
            if family == UInt8(AF_LINK) && (flags & IFF_UP) != 0 && (flags & IFF_RUNNING) != 0 && !name.hasPrefix("lo") {
                if let data = p.pointee.ifa_data {
                    let ifData = data.assumingMemoryBound(to: if_data.self).pointee
                    totalIn += UInt64(ifData.ifi_ibytes)
                    totalOut += UInt64(ifData.ifi_obytes)
                }
            }
            ptr = p.pointee.ifa_next
        }
        return (totalIn, totalOut)
    }
    
    // MARK: - Lightweight BSD Socket TCP Ping Radar
    
    private func measureTCPPing(host: String, port: UInt16) -> Double? {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        var hints = addrinfo()
        hints.ai_family = AF_INET
        hints.ai_socktype = SOCK_STREAM
        
        var res: UnsafeMutablePointer<addrinfo>?
        guard getaddrinfo(host, "\(port)", &hints, &res) == 0, let serverAddr = res else {
            return nil
        }
        defer { freeaddrinfo(res) }
        
        let sock = socket(serverAddr.pointee.ai_family, serverAddr.pointee.ai_socktype, serverAddr.pointee.ai_protocol)
        guard sock >= 0 else { return nil }
        defer { close(sock) }
        
        // Set 800ms timeout for snappy responsiveness
        var timeout = timeval(tv_sec: 0, tv_usec: 800_000)
        setsockopt(sock, SOL_SOCKET, SO_RCVTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))
        setsockopt(sock, SOL_SOCKET, SO_SNDTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))
        
        let ret = connect(sock, serverAddr.pointee.ai_addr, serverAddr.pointee.ai_addrlen)
        guard ret == 0 else { return nil }
        
        let elapsed = (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0
        return elapsed
    }
    
    // MARK: - Formatters & Evaluators
    
    private func formatSpeed(_ bytesPerSec: Double) -> String {
        if bytesPerSec < 1024.0 {
            return "0 KB/s"
        } else if bytesPerSec < 1024.0 * 1024.0 {
            let kb = bytesPerSec / 1024.0
            return kb >= 100 ? String(format: "%.0f KB/s", kb) : String(format: "%.1f KB/s", kb)
        } else if bytesPerSec < 1024.0 * 1024.0 * 1024.0 {
            let mb = bytesPerSec / (1024.0 * 1024.0)
            return String(format: "%.1f MB/s", mb)
        } else {
            let gb = bytesPerSec / (1024.0 * 1024.0 * 1024.0)
            return String(format: "%.2f GB/s", gb)
        }
    }
    
    private func evaluateQuality(_ ping: Double?) -> PingQuality {
        guard let p = ping else { return .unknown }
        if p < 45.0 {
            return .excellent
        } else if p < 90.0 {
            return .good
        } else if p < 160.0 {
            return .fair
        } else {
            return .poor
        }
    }
}
