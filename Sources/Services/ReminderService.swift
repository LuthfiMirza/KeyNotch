import Foundation
import Combine

public struct NoteItem: Identifiable, Codable, Equatable {
    public var id: UUID
    public var text: String
    public var isCompleted: Bool
    public var createdAt: Date
    
    public init(id: UUID = UUID(), text: String, isCompleted: Bool = false, createdAt: Date = Date()) {
        self.id = id
        self.text = text
        self.isCompleted = isCompleted
        self.createdAt = createdAt
    }
}

public final class ReminderService: ObservableObject {
    public static let shared = ReminderService()
    
    @Published public var notes: [NoteItem] = []
    
    private let storageKey = "keynotch_quick_notes"
    
    public var pendingCount: Int {
        notes.filter { !$0.isCompleted }.count
    }
    
    public var completedCount: Int {
        notes.filter { $0.isCompleted }.count
    }
    
    private init() {
        loadNotes()
    }
    
    public func addNote(text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let newItem = NoteItem(text: trimmed)
        notes.insert(newItem, at: 0)
        saveNotes()
    }
    
    public func toggleNote(_ note: NoteItem) {
        if let idx = notes.firstIndex(where: { $0.id == note.id }) {
            notes[idx].isCompleted.toggle()
            saveNotes()
        }
    }
    
    public func deleteNote(_ note: NoteItem) {
        notes.removeAll { $0.id == note.id }
        saveNotes()
    }
    
    public func clearCompleted() {
        notes.removeAll { $0.isCompleted }
        saveNotes()
    }
    
    private func saveNotes() {
        if let data = try? JSONEncoder().encode(notes) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }
    
    private func loadNotes() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let saved = try? JSONDecoder().decode([NoteItem].self, from: data) {
            self.notes = saved
        } else {
            self.notes = []
        }
    }
}

