import Cocoa
import SwiftUI
import UniformTypeIdentifiers

public struct StagedFile: Identifiable, Equatable {
    public let id: UUID
    public let url: URL
    public let name: String
    public let icon: NSImage
    public let isImage: Bool
    public let fileSizeString: String
    
    public init(id: UUID = UUID(), url: URL) {
        self.id = id
        self.url = url
        self.name = url.lastPathComponent
        self.icon = NSWorkspace.shared.icon(forFile: url.path)
        
        let ext = url.pathExtension.lowercased()
        self.isImage = ["png", "jpg", "jpeg", "webp", "heic", "tiff", "gif", "bmp"].contains(ext)
        
        if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
           let size = attrs[.size] as? Int64 {
            let formatter = ByteCountFormatter()
            formatter.allowedUnits = [.useKB, .useMB]
            formatter.countStyle = .file
            self.fileSizeString = formatter.string(fromByteCount: size)
        } else {
            self.fileSizeString = "--"
        }
    }
    
    public static func == (lhs: StagedFile, rhs: StagedFile) -> Bool {
        lhs.id == rhs.id && lhs.url == rhs.url
    }
}

public final class FileShelfService: ObservableObject {
    public static let shared = FileShelfService()
    
    @Published public private(set) var stagedFiles: [StagedFile] = []
    
    private let storageKey = "keynotch_file_shelf_paths_v1"
    
    private init() {
        loadPersistedFiles()
    }
    
    public func addFile(url: URL) {
        // Prevent duplicate URLs
        guard !stagedFiles.contains(where: { $0.url.path == url.path }) else { return }
        let file = StagedFile(url: url)
        withAnimation(.spring(response: 0.35, dampingFraction: 0.78)) {
            stagedFiles.append(file)
        }
        saveFiles()
    }
    
    public func addFiles(from providers: [NSItemProvider]) {
        for provider in providers {
            provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { [weak self] (urlData, error) in
                guard let self = self else { return }
                var fileURL: URL? = nil
                
                if let url = urlData as? URL {
                    fileURL = url
                } else if let data = urlData as? Data,
                          let url = URL(dataRepresentation: data, relativeTo: nil) {
                    fileURL = url
                } else if let str = urlData as? String,
                          let url = URL(string: str) {
                    fileURL = url
                }
                
                if let validURL = fileURL {
                    DispatchQueue.main.async {
                        self.addFile(url: validURL)
                    }
                }
            }
        }
    }
    
    public func removeFile(id: UUID) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.78)) {
            stagedFiles.removeAll { $0.id == id }
        }
        saveFiles()
    }
    
    public func clearAll() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.78)) {
            stagedFiles.removeAll()
        }
        saveFiles()
    }
    
    // MARK: - Persistence across App & Notch restarts
    
    private func saveFiles() {
        let paths = stagedFiles.map { $0.url.path }
        UserDefaults.standard.set(paths, forKey: storageKey)
    }
    
    private func loadPersistedFiles() {
        guard let paths = UserDefaults.standard.stringArray(forKey: storageKey) else { return }
        var loaded: [StagedFile] = []
        for path in paths {
            if FileManager.default.fileExists(atPath: path) {
                let url = URL(fileURLWithPath: path)
                loaded.append(StagedFile(url: url))
            }
        }
        self.stagedFiles = loaded
    }
}
