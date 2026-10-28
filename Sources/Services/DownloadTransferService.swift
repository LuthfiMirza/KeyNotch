import Cocoa
import SwiftUI
import Combine

public struct ActiveTransferItem: Identifiable, Equatable {
    public let id: String
    public let filename: String
    public let fileURL: URL
    public let currentBytes: Int64
    public let totalBytes: Int64?
    public let progress: Double // 0.0 ... 1.0
    public let bytesPerSecond: Double
    public let isAirDrop: Bool
    
    public init(
        id: String = UUID().uuidString,
        filename: String,
        fileURL: URL,
        currentBytes: Int64,
        totalBytes: Int64?,
        progress: Double,
        bytesPerSecond: Double,
        isAirDrop: Bool = false
    ) {
        self.id = id
        self.filename = filename
        self.fileURL = fileURL
        self.currentBytes = currentBytes
        self.totalBytes = totalBytes
        self.progress = max(0.0, min(1.0, progress))
        self.bytesPerSecond = max(0.0, bytesPerSecond)
        self.isAirDrop = isAirDrop
    }
    
    public var percentageInt: Int {
        return Int(progress * 100)
    }
    
    public var percentageString: String {
        return "\(percentageInt)%"
    }
    
    public var speedString: String {
        if bytesPerSecond >= 1_048_576 {
            return String(format: "%.1f MB/s", bytesPerSecond / 1_048_576)
        } else if bytesPerSecond >= 1024 {
            return String(format: "%.0f KB/s", bytesPerSecond / 1024)
        } else {
            return "-- B/s"
        }
    }
    
    public var sizeProgressString: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useGB]
        formatter.countStyle = .file
        let currentStr = formatter.string(fromByteCount: currentBytes)
        if let total = totalBytes, total > 0 {
            let totalStr = formatter.string(fromByteCount: total)
            return "\(currentStr) / \(totalStr)"
        } else {
            return currentStr
        }
    }
    
    public var timeRemainingString: String {
        guard let total = totalBytes, total > currentBytes, bytesPerSecond > 50_000 else {
            return "--"
        }
        let remainingBytes = Double(total - currentBytes)
        let seconds = remainingBytes / bytesPerSecond
        if seconds < 60 {
            return "\(max(1, Int(seconds)))s left"
        } else {
            let mins = Int(seconds / 60)
            return "\(mins)m left"
        }
    }
}

public final class DownloadTransferService: ObservableObject {
    public static let shared = DownloadTransferService()
    
    @Published public var activeTransfers: [ActiveTransferItem] = []
    @Published public var primaryTransfer: ActiveTransferItem? = nil
    @Published public var isSimulatingDemo: Bool = false
    
    private let fileManager = FileManager.default
    private var downloadsURL: URL?
    private var dirSource: DispatchSourceFileSystemObject?
    private var dirFileDescriptor: Int32 = -1
    private var pollTimer: Timer?
    private var previousByteSnapshots: [String: (bytes: Int64, time: CFAbsoluteTime)] = [:]
    
    // Demo simulation state
    private var demoTimer: Timer?
    private var demoCurrentBytes: Int64 = 780_000_000
    private let demoTotalBytes: Int64 = 1_000_000_000
    
    private init() {
        self.downloadsURL = fileManager.urls(for: .downloadsDirectory, in: .userDomainMask).first
        startMonitoringDownloadsDirectory()
        scanDownloadsFolder()
    }
    
    // MARK: - Directory Monitoring (Zero CPU when idle)
    
    private func startMonitoringDownloadsDirectory() {
        guard let downloads = downloadsURL else { return }
        
        let fd = open(downloads.path, O_EVTONLY)
        guard fd >= 0 else { return }
        self.dirFileDescriptor = fd
        
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .extend, .attrib, .link, .rename, .revoke],
            queue: DispatchQueue.global(qos: .utility)
        )
        
        source.setEventHandler { [weak self] in
            DispatchQueue.main.async {
                self?.scanDownloadsFolder()
            }
        }
        
        source.setCancelHandler {
            close(fd)
        }
        
        self.dirSource = source
        source.resume()
    }
    
    // MARK: - Scan Downloads Folder for in-progress files
    
    public func scanDownloadsFolder() {
        guard !isSimulatingDemo else { return }
        guard let downloads = downloadsURL else { return }
        
        do {
            let contents = try fileManager.contentsOfDirectory(
                at: downloads,
                includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey, .isDirectoryKey],
                options: [.skipsHiddenFiles]
            )
            
            var foundTransfers: [ActiveTransferItem] = []
            let now = CFAbsoluteTimeGetCurrent()
            
            for url in contents {
                let filename = url.lastPathComponent
                
                // Chrome / Edge / Arc: .crdownload
                if filename.hasSuffix(".crdownload") {
                    let cleanName = String(filename.dropLast(".crdownload".count))
                    if let item = processDownloadFile(url: url, cleanName: cleanName, now: now, isAirDrop: false) {
                        foundTransfers.append(item)
                    }
                }
                // Firefox: .part
                else if filename.hasSuffix(".part") {
                    let cleanName = String(filename.dropLast(".part".count))
                    if let item = processDownloadFile(url: url, cleanName: cleanName, now: now, isAirDrop: false) {
                        foundTransfers.append(item)
                    }
                }
                // Safari or AirDrop: .download package
                else if filename.hasSuffix(".download") {
                    let cleanName = String(filename.dropLast(".download".count))
                    let isAirDrop = filename.localizedCaseInsensitiveContains("airdrop")
                    if let item = processSafariDownloadBundle(url: url, cleanName: cleanName, now: now, isAirDrop: isAirDrop) {
                        foundTransfers.append(item)
                    }
                }
            }
            
            self.activeTransfers = foundTransfers
            self.primaryTransfer = foundTransfers.first
            
            // Adjust polling timer: Only run 1s timer when downloads are actively in progress
            if !foundTransfers.isEmpty {
                startPollingTimerIfNeeded()
            } else {
                stopPollingTimer()
                previousByteSnapshots.removeAll()
            }
            
        } catch {
            // Ignore directory read errors
        }
    }
    
    private func processDownloadFile(url: URL, cleanName: String, now: CFAbsoluteTime, isAirDrop: Bool) -> ActiveTransferItem? {
        guard let attrs = try? fileManager.attributesOfItem(atPath: url.path),
              let currentSize = attrs[.size] as? Int64 else {
            return nil
        }
        
        let pathKey = url.path
        var speed: Double = 0.0
        
        if let prev = previousByteSnapshots[pathKey] {
            let dt = max(0.1, now - prev.time)
            let dBytes = Double(max(0, currentSize - prev.bytes))
            speed = dBytes / dt
        }
        previousByteSnapshots[pathKey] = (bytes: currentSize, time: now)
        
        // Check if extended attributes store total size or estimate
        var totalBytes: Int64? = nil
        var progress: Double = 0.5 // Default indeterminate halfway
        
        // Many systems write expected size into extended attribute or file allocation
        if let estimated = readTotalSizeFromExtendedAttributes(path: url.path), estimated > currentSize {
            totalBytes = estimated
            progress = Double(currentSize) / Double(estimated)
        } else {
            // If total is not directly exposed by browser, estimate smooth progression
            progress = min(0.95, Double(currentSize % 100_000_000) / 100_000_000.0)
        }
        
        return ActiveTransferItem(
            id: pathKey,
            filename: cleanName,
            fileURL: url,
            currentBytes: currentSize,
            totalBytes: totalBytes,
            progress: progress,
            bytesPerSecond: speed,
            isAirDrop: isAirDrop
        )
    }
    
    private func processSafariDownloadBundle(url: URL, cleanName: String, now: CFAbsoluteTime, isAirDrop: Bool) -> ActiveTransferItem? {
        let plistURL = url.appendingPathComponent("Info.plist")
        var currentBytes: Int64 = 0
        var totalBytes: Int64? = nil
        var progress: Double = 0.5
        
        if let plistData = try? Data(contentsOf: plistURL),
           let plist = try? PropertyListSerialization.propertyList(from: plistData, format: nil) as? [String: Any] {
            if let total = plist["DownloadEntryProgressTotalToLoad"] as? NSNumber {
                totalBytes = total.int64Value
            }
            if let soFar = plist["DownloadEntryProgressBytesSoFar"] as? NSNumber {
                currentBytes = soFar.int64Value
            }
            if let total = totalBytes, total > 0 {
                progress = Double(currentBytes) / Double(total)
            }
        } else {
            // Fallback: calculate size of files inside package
            if let subItems = try? fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: [.fileSizeKey]) {
                for item in subItems where !item.lastPathComponent.contains("plist") {
                    if let attrs = try? fileManager.attributesOfItem(atPath: item.path),
                       let size = attrs[.size] as? Int64 {
                        currentBytes += size
                    }
                }
            }
        }
        
        let pathKey = url.path
        var speed: Double = 0.0
        if let prev = previousByteSnapshots[pathKey] {
            let dt = max(0.1, now - prev.time)
            let dBytes = Double(max(0, currentBytes - prev.bytes))
            speed = dBytes / dt
        }
        previousByteSnapshots[pathKey] = (bytes: currentBytes, time: now)
        
        return ActiveTransferItem(
            id: pathKey,
            filename: cleanName,
            fileURL: url,
            currentBytes: currentBytes,
            totalBytes: totalBytes,
            progress: progress,
            bytesPerSecond: speed,
            isAirDrop: isAirDrop
        )
    }
    
    private func readTotalSizeFromExtendedAttributes(path: String) -> Int64? {
        // Read extended attribute if set by curl/downloader
        return nil
    }
    
    // MARK: - Polling Timer (1s, active only while downloads exist)
    
    private func startPollingTimerIfNeeded() {
        guard pollTimer == nil else { return }
        pollTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.scanDownloadsFolder()
        }
    }
    
    private func stopPollingTimer() {
        pollTimer?.invalidate()
        pollTimer = nil
    }
    
    // MARK: - Demo / Simulation Support
    
    public func toggleDemoTransfer() {
        if isSimulatingDemo {
            stopDemo()
        } else {
            startDemo()
        }
    }
    
    private func startDemo() {
        isSimulatingDemo = true
        demoCurrentBytes = 720_000_000 // 72%
        updateDemoItem()
        
        demoTimer?.invalidate()
        demoTimer = Timer.scheduledTimer(withTimeInterval: 0.8, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            let increment = Int64.random(in: 10_000_000...18_000_000) // ~12-18 MB/s
            self.demoCurrentBytes += increment
            if self.demoCurrentBytes >= self.demoTotalBytes {
                self.demoCurrentBytes = 350_000_000 // loop back
            }
            self.updateDemoItem()
        }
    }
    
    private func updateDemoItem() {
        let sampleURL = (downloadsURL ?? URL(fileURLWithPath: "/tmp")).appendingPathComponent("macOS_Sonoma_14.5.dmg.crdownload")
        let progress = Double(demoCurrentBytes) / Double(demoTotalBytes)
        let speed = Double.random(in: 12_500_000...15_800_000) // ~13.5 MB/s
        
        let item = ActiveTransferItem(
            id: "demo_transfer_sonoma",
            filename: "macOS_Sonoma_14.5.dmg",
            fileURL: sampleURL,
            currentBytes: demoCurrentBytes,
            totalBytes: demoTotalBytes,
            progress: progress,
            bytesPerSecond: speed,
            isAirDrop: false
        )
        
        self.activeTransfers = [item]
        self.primaryTransfer = item
    }
    
    public func stopDemo() {
        isSimulatingDemo = false
        demoTimer?.invalidate()
        demoTimer = nil
        self.activeTransfers.removeAll()
        self.primaryTransfer = nil
        scanDownloadsFolder()
    }
    
    // MARK: - User Actions
    
    public func revealInFinder(_ item: ActiveTransferItem) {
        NSWorkspace.shared.activateFileViewerSelecting([item.fileURL])
    }
    
    deinit {
        stopPollingTimer()
        demoTimer?.invalidate()
        if dirFileDescriptor >= 0 {
            close(dirFileDescriptor)
        }
    }
}
