import Cocoa
import SwiftUI
import Combine
import SQLite3

public struct WhatsAppMessage: Identifiable, Equatable {
    public let id: Int64
    public let sender: String
    public let text: String
    public let timestamp: Date
    public let isGroup: Bool
    
    public init(id: Int64, sender: String, text: String, timestamp: Date = Date(), isGroup: Bool = false) {
        self.id = id
        self.sender = sender
        self.text = text
        self.timestamp = timestamp
        self.isGroup = isGroup
    }
}

public final class WhatsAppNotificationService: ObservableObject {
    public static let shared = WhatsAppNotificationService()
    
    @Published public var isMonitoring: Bool = false
    @Published public var lastMessage: WhatsAppMessage? = nil
    @Published public var isEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: "keynotch_whatsapp_notifications_enabled")
            if isEnabled {
                startMonitoring()
            } else {
                stopMonitoring()
            }
        }
    }
    
    @Published public var hideMessagePreview: Bool {
        didSet {
            UserDefaults.standard.set(hideMessagePreview, forKey: "keynotch_whatsapp_hide_preview")
        }
    }
    
    private let queue = DispatchQueue(label: "com.keynotch.whatsappmonitor", qos: .utility)
    private var dirSource: DispatchSourceFileSystemObject?
    private var walSource: DispatchSourceFileSystemObject?
    private var callWalSource: DispatchSourceFileSystemObject?
    private var debounceWorkItem: DispatchWorkItem?
    private var lastSeenPK: Int64 = 0
    private var lastSeenCallPK: Int64 = 0
    
    private let sharedContainerURL: URL
    private let dbURL: URL
    private let walURL: URL
    private let callDBURL: URL
    private let callWalURL: URL
    
    private init() {
        self.isEnabled = UserDefaults.standard.object(forKey: "keynotch_whatsapp_notifications_enabled") as? Bool ?? true
        self.hideMessagePreview = UserDefaults.standard.bool(forKey: "keynotch_whatsapp_hide_preview")
        
        self.sharedContainerURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Group Containers/group.net.whatsapp.WhatsApp.shared")
        self.dbURL = sharedContainerURL.appendingPathComponent("ChatStorage.sqlite")
        self.walURL = sharedContainerURL.appendingPathComponent("ChatStorage.sqlite-wal")
        self.callDBURL = sharedContainerURL.appendingPathComponent("CallHistory.sqlite")
        self.callWalURL = sharedContainerURL.appendingPathComponent("CallHistory.sqlite-wal")
        
        if isEnabled {
            // Establish baseline on background queue so we don't notify past messages or calls
            queue.async { [weak self] in
                self?.establishBaseline()
                self?.startMonitoring()
            }
        }
    }
    
    deinit {
        stopMonitoring()
    }
    
    // MARK: - Monitoring Setup (0.0% Idle CPU Event-Driven)
    
    public func startMonitoring() {
        guard !isMonitoring else { return }
        guard FileManager.default.fileExists(atPath: dbURL.path) else {
            return
        }
        
        // 1. Monitor the shared container directory for file modifications/checkpoints
        let dirPath = sharedContainerURL.path
        let dirFD = open(dirPath, O_EVTONLY)
        if dirFD >= 0 {
            let src = DispatchSource.makeFileSystemObjectSource(
                fileDescriptor: dirFD,
                eventMask: [.write, .extend, .attrib],
                queue: queue
            )
            src.setEventHandler { [weak self] in
                self?.scheduleCheck()
            }
            src.setCancelHandler {
                close(dirFD)
            }
            src.resume()
            self.dirSource = src
        }
        
        // 2. Monitor WAL files directly if they exist
        attachWALSourceIfNeeded()
        attachCallWALSourceIfNeeded()
        
        DispatchQueue.main.async {
            self.isMonitoring = true
        }
    }
    
    private func attachWALSourceIfNeeded() {
        guard walSource == nil else { return }
        let walPath = walURL.path
        guard FileManager.default.fileExists(atPath: walPath) else { return }
        
        let walFD = open(walPath, O_EVTONLY)
        guard walFD >= 0 else { return }
        
        let src = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: walFD,
            eventMask: [.write, .extend],
            queue: queue
        )
        src.setEventHandler { [weak self] in
            self?.scheduleCheck()
        }
        src.setCancelHandler {
            close(walFD)
        }
        src.resume()
        self.walSource = src
    }
    
    private func attachCallWALSourceIfNeeded() {
        guard callWalSource == nil else { return }
        let walPath = callWalURL.path
        guard FileManager.default.fileExists(atPath: walPath) else { return }
        
        let walFD = open(walPath, O_EVTONLY)
        guard walFD >= 0 else { return }
        
        let src = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: walFD,
            eventMask: [.write, .extend],
            queue: queue
        )
        src.setEventHandler { [weak self] in
            self?.scheduleCheck()
        }
        src.setCancelHandler {
            close(walFD)
        }
        src.resume()
        self.callWalSource = src
    }
    
    public func stopMonitoring() {
        dirSource?.cancel()
        dirSource = nil
        walSource?.cancel()
        walSource = nil
        callWalSource?.cancel()
        callWalSource = nil
        debounceWorkItem?.cancel()
        debounceWorkItem = nil
        
        DispatchQueue.main.async {
            self.isMonitoring = false
        }
    }
    
    // MARK: - Event Debouncing & Database Inspection
    
    private func scheduleCheck() {
        debounceWorkItem?.cancel()
        
        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            self.checkForNewMessages()
            self.checkForNewCalls()
            self.attachWALSourceIfNeeded()
            self.attachCallWALSourceIfNeeded()
        }
        self.debounceWorkItem = workItem
        queue.asyncAfter(deadline: .now() + 0.35, execute: workItem)
    }
    
    private func establishBaseline() {
        // 1. Messages baseline
        var db: OpaquePointer?
        let uri = "file:\(dbURL.path)?mode=ro"
        if sqlite3_open_v2(uri, &db, SQLITE_OPEN_READONLY | SQLITE_OPEN_URI | SQLITE_OPEN_NOMUTEX, nil) == SQLITE_OK {
            var stmt: OpaquePointer?
            let sql = "SELECT MAX(Z_PK) FROM ZWAMESSAGE WHERE ZISFROMME = 0;"
            if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
                if sqlite3_step(stmt) == SQLITE_ROW {
                    self.lastSeenPK = sqlite3_column_int64(stmt, 0)
                }
                sqlite3_finalize(stmt)
            }
            sqlite3_close(db)
        }
        
        // 2. Call history baseline
        var callDB: OpaquePointer?
        let callUri = "file:\(callDBURL.path)?mode=ro"
        if sqlite3_open_v2(callUri, &callDB, SQLITE_OPEN_READONLY | SQLITE_OPEN_URI | SQLITE_OPEN_NOMUTEX, nil) == SQLITE_OK {
            var stmt: OpaquePointer?
            let sql = "SELECT MAX(Z_PK) FROM ZWAAGGREGATECALLEVENT;"
            if sqlite3_prepare_v2(callDB, sql, -1, &stmt, nil) == SQLITE_OK {
                if sqlite3_step(stmt) == SQLITE_ROW {
                    self.lastSeenCallPK = sqlite3_column_int64(stmt, 0)
                }
                sqlite3_finalize(stmt)
            }
            sqlite3_close(callDB)
        }
    }
    
    private func checkForNewMessages() {
        guard isEnabled else { return }
        
        var db: OpaquePointer?
        let uri = "file:\(dbURL.path)?mode=ro"
        guard sqlite3_open_v2(uri, &db, SQLITE_OPEN_READONLY | SQLITE_OPEN_URI | SQLITE_OPEN_NOMUTEX, nil) == SQLITE_OK else {
            return
        }
        defer { sqlite3_close(db) }
        
        let query = """
        SELECT 
            m.Z_PK,
            COALESCE(s.ZPARTNERNAME, 'WhatsApp'),
            COALESCE(m.ZTEXT, ''),
            m.ZMESSAGETYPE
        FROM ZWAMESSAGE m
        LEFT JOIN ZWACHATSESSION s ON m.ZCHATSESSION = s.Z_PK
        WHERE m.ZISFROMME = 0 AND m.Z_PK > ?
        ORDER BY m.Z_PK DESC
        LIMIT 1;
        """
        
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK else {
            return
        }
        defer { sqlite3_finalize(stmt) }
        
        sqlite3_bind_int64(stmt, 1, lastSeenPK)
        
        if sqlite3_step(stmt) == SQLITE_ROW {
            let pk = sqlite3_column_int64(stmt, 0)
            let rawSender = String(cString: sqlite3_column_text(stmt, 1))
            let rawText = String(cString: sqlite3_column_text(stmt, 2))
            let msgType = sqlite3_column_int(stmt, 3)
            
            // Advance baseline
            self.lastSeenPK = pk
            
            let displayBody = self.formatMessageBody(text: rawText, type: msgType)
            let msg = WhatsAppMessage(id: pk, sender: rawSender, text: displayBody)
            
            DispatchQueue.main.async {
                self.lastMessage = msg
                self.presentNotification(sender: rawSender, body: displayBody)
            }
        }
    }
    
    private func formatMessageBody(text: String, type: Int32) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            return trimmed
        }
        switch type {
        case 1: return "📷 Foto"
        case 2: return "🎥 Video"
        case 3: return "🎙️ Pesan Suara"
        case 5: return "📍 Lokasi"
        case 8: return "📄 Dokumen"
        case 15: return "Stiker"
        default: return "Pesan Baru"
        }
    }
    
    // MARK: - Dynamic Island Notification Presentation
    
    private func presentNotification(sender: String, body: String) {
        let subtitleText = hideMessagePreview ? "Pesan WhatsApp Baru" : body
        
        IslandState.shared.triggerHUD(
            HUDPayload(
                type: .whatsapp,
                title: sender,
                subtitle: subtitleText,
                iconName: "message.fill",
                rightDetail: "WhatsApp",
                isSuccess: true
            ),
            duration: 4.5
        )
    }
    
    // MARK: - Actions
    
    public func openWhatsApp() {
        let whatsappURL = URL(fileURLWithPath: "/Applications/WhatsApp.app")
        if FileManager.default.fileExists(atPath: whatsappURL.path) {
            NSWorkspace.shared.openApplication(
                at: whatsappURL,
                configuration: NSWorkspace.OpenConfiguration()
            )
        } else if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "net.whatsapp.WhatsApp") {
            NSWorkspace.shared.openApplication(at: appURL, configuration: NSWorkspace.OpenConfiguration())
        }
    }
    
    public func simulateIncomingMessage(sender: String = "Budi Santoso", text: String = "Halo bro, meeting jam 2 siang di cafe ya! ☕️") {
        let msg = WhatsAppMessage(id: Int64(Date().timeIntervalSince1970), sender: sender, text: text)
        self.lastMessage = msg
        presentNotification(sender: sender, body: text)
    }
    
    // MARK: - Incoming Call Detection & Presentation
    
    private func checkForNewCalls() {
        guard isEnabled else { return }
        guard FileManager.default.fileExists(atPath: callDBURL.path) else { return }
        
        var db: OpaquePointer?
        let uri = "file:\(callDBURL.path)?mode=ro"
        guard sqlite3_open_v2(uri, &db, SQLITE_OPEN_READONLY | SQLITE_OPEN_URI | SQLITE_OPEN_NOMUTEX, nil) == SQLITE_OK else {
            return
        }
        defer { sqlite3_close(db) }
        
        let query = """
        SELECT 
            a.Z_PK,
            a.ZINCOMING,
            a.ZVIDEO,
            COALESCE(c.ZGROUPCALLCREATORUSERJIDSTRING, p.ZJIDSTRING, '')
        FROM ZWAAGGREGATECALLEVENT a
        LEFT JOIN ZWACDCALLEVENT c ON c.Z1CALLEVENTS = a.Z_PK
        LEFT JOIN ZWACDCALLEVENTPARTICIPANT p ON p.Z1PARTICIPANTS = c.Z_PK
        WHERE a.ZINCOMING = 1 AND a.Z_PK > ?
        ORDER BY a.Z_PK DESC
        LIMIT 1;
        """
        
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK else {
            return
        }
        defer { sqlite3_finalize(stmt) }
        
        sqlite3_bind_int64(stmt, 1, lastSeenCallPK)
        
        if sqlite3_step(stmt) == SQLITE_ROW {
            let pk = sqlite3_column_int64(stmt, 0)
            let isVideo = sqlite3_column_int(stmt, 2) == 1
            let rawJID = String(cString: sqlite3_column_text(stmt, 3))
            
            // Advance call baseline
            self.lastSeenCallPK = pk
            
            let callerName = resolveCallerName(rawJID: rawJID)
            
            DispatchQueue.main.async {
                self.presentCallNotification(caller: callerName, isVideo: isVideo)
            }
        }
    }
    
    private func resolveCallerName(rawJID: String) -> String {
        let trimmed = rawJID.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return "Panggilan WhatsApp"
        }
        
        // Strip domain like @lid or @s.whatsapp.net to get user ID
        let cleanJID = trimmed.components(separatedBy: "@").first ?? trimmed
        
        var chatDB: OpaquePointer?
        let uri = "file:\(dbURL.path)?mode=ro"
        guard sqlite3_open_v2(uri, &chatDB, SQLITE_OPEN_READONLY | SQLITE_OPEN_URI | SQLITE_OPEN_NOMUTEX, nil) == SQLITE_OK else {
            return cleanJID.isEmpty ? "Panggilan WhatsApp" : cleanJID
        }
        defer { sqlite3_close(chatDB) }
        
        let query = "SELECT ZPARTNERNAME FROM ZWACHATSESSION WHERE ZCONTACTJID LIKE '%' || ? || '%' LIMIT 1;"
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(chatDB, query, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, (cleanJID as NSString).utf8String, -1, nil)
            if sqlite3_step(stmt) == SQLITE_ROW {
                if let text = sqlite3_column_text(stmt, 0) {
                    let name = String(cString: text).trimmingCharacters(in: .whitespacesAndNewlines)
                    sqlite3_finalize(stmt)
                    if !name.isEmpty {
                        return name
                    }
                }
            }
            sqlite3_finalize(stmt)
        }
        
        return cleanJID.isEmpty ? "Panggilan WhatsApp" : cleanJID
    }
    
    public func presentCallNotification(caller: String, isVideo: Bool) {
        let subtitle = isVideo ? "Panggilan Video Masuk..." : "Panggilan Suara Masuk..."
        let icon = isVideo ? "video.fill" : "phone.arrow.down.left.fill"
        let detail = isVideo ? "Video Call" : "Voice Call"
        
        IslandState.shared.triggerHUD(
            HUDPayload(
                type: .incomingCall,
                title: caller,
                subtitle: subtitle,
                iconName: icon,
                rightDetail: detail,
                isSuccess: true
            ),
            duration: 15.0 // Ringing lasts 15s or until Answer/Decline
        )
    }
    
    public func simulateIncomingCall(caller: String = "Eca 🥰", isVideo: Bool = false) {
        presentCallNotification(caller: caller, isVideo: isVideo)
    }
}
