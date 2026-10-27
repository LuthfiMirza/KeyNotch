import SwiftUI

public struct NoteItem: Identifiable, Codable, Equatable {
    public var id: UUID = UUID()
    public var text: String
    public var isCompleted: Bool
    public var createdAt: Date
    
    public init(text: String, isCompleted: Bool = false, createdAt: Date = Date()) {
        self.text = text
        self.isCompleted = isCompleted
        self.createdAt = createdAt
    }
}

public struct NotesTimerTabView: View {
    @ObservedObject var pomodoro = PomodoroService.shared
    @State private var notes: [NoteItem] = []
    @State private var newNoteText: String = ""
    
    private let notesKey = "keynotch_quick_notes"
    
    public init() {}
    
    public var body: some View {
        HStack(alignment: .top, spacing: 14) {
            // MARK: - Left Column: Quick Notes & Reminders
            notesColumn
                .frame(maxWidth: .infinity)
            
            Divider()
                .background(Color.white.opacity(0.12))
            
            // MARK: - Right Column: Focus / Pomodoro Timer
            pomodoroColumn
                .frame(width: 220)
        }
        .padding(.horizontal, 14)
        .padding(.top, 2)
        .onAppear {
            loadNotes()
        }
    }
    
    // MARK: - Notes Column
    
    private var notesColumn: some View {
        VStack(spacing: 8) {
            // Header & Count
            HStack {
                HStack(spacing: 5) {
                    Image(systemName: "checklist")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.yellow)
                    Text("Reminders")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                }
                
                Spacer()
                
                let remaining = notes.filter { !$0.isCompleted }.count
                Text("\(remaining) pending")
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.5))
            }
            
            // New Task Input
            HStack(spacing: 6) {
                TextField("Add task...", text: $newNoteText, onCommit: {
                    addNote()
                })
                .textFieldStyle(PlainTextFieldStyle())
                .font(.system(size: 11))
                .foregroundColor(.white)
                
                Button(action: {
                    addNote()
                }) {
                    Text("Add")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.black)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(newNoteText.trimmingCharacters(in: .whitespaces).isEmpty ? Color.gray : Color.yellow)
                        .clipShape(Capsule())
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(newNoteText.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(Color.white.opacity(0.07))
            .cornerRadius(8)
            
            // Scrollable Task List
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 5) {
                    if notes.isEmpty {
                        VStack(spacing: 4) {
                            Text("No reminders")
                                .font(.system(size: 11))
                                .foregroundColor(.white.opacity(0.4))
                        }
                        .padding(.top, 20)
                    } else {
                        ForEach(notes) { note in
                            noteRow(note)
                        }
                    }
                }
            }
            .frame(height: 100)
        }
    }
    
    private func noteRow(_ note: NoteItem) -> some View {
        HStack(spacing: 8) {
            // iOS Style Circular Checkbox
            Button(action: {
                toggleNote(note)
            }) {
                ZStack {
                    Circle()
                        .stroke(note.isCompleted ? Color.green : Color.white.opacity(0.4), lineWidth: 1.5)
                        .frame(width: 14, height: 14)
                    
                    if note.isCompleted {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 14, height: 14)
                        Image(systemName: "checkmark")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.black)
                    }
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            // Note Text with Strikethrough
            Text(note.text)
                .font(.system(size: 11))
                .foregroundColor(note.isCompleted ? .white.opacity(0.35) : .white)
                .strikethrough(note.isCompleted, color: .white.opacity(0.4))
                .lineLimit(1)
            
            Spacer()
            
            // Delete Note Button
            Button(action: {
                deleteNote(note)
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.white.opacity(0.3))
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(Color.white.opacity(note.isCompleted ? 0.02 : 0.05))
        .cornerRadius(6)
    }
    
    private func addNote() {
        let trimmed = newNoteText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let newItem = NoteItem(text: trimmed)
        notes.insert(newItem, at: 0)
        newNoteText = ""
        saveNotes()
    }
    
    private func toggleNote(_ note: NoteItem) {
        if let idx = notes.firstIndex(where: { $0.id == note.id }) {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                notes[idx].isCompleted.toggle()
            }
            saveNotes()
        }
    }
    
    private func deleteNote(_ note: NoteItem) {
        withAnimation {
            notes.removeAll { $0.id == note.id }
        }
        saveNotes()
    }
    
    private func saveNotes() {
        if let data = try? JSONEncoder().encode(notes) {
            UserDefaults.standard.set(data, forKey: notesKey)
        }
    }
    
    private func loadNotes() {
        if let data = UserDefaults.standard.data(forKey: notesKey),
           let saved = try? JSONDecoder().decode([NoteItem].self, from: data) {
            self.notes = saved
        }
    }
    
    // MARK: - Pomodoro Focus Timer Column
    
    private var pomodoroColumn: some View {
        VStack(spacing: 8) {
            // Header
            HStack {
                HStack(spacing: 5) {
                    Image(systemName: "timer")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.green)
                    Text("Focus Timer")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                }
                Spacer()
                Text(pomodoro.currentPresetName)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white.opacity(0.55))
            }
            
            // Countdown Display & Progress Ring
            HStack(spacing: 14) {
                // Circular Progress
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.12), lineWidth: 4)
                    
                    Circle()
                        .trim(from: 0, to: CGFloat(pomodoro.progress))
                        .stroke(
                            Color.green,
                            style: StrokeStyle(lineWidth: 4, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 1.0), value: pomodoro.progress)
                    
                    Image(systemName: pomodoro.isRunning ? "flame.fill" : "hourglass")
                        .font(.system(size: 12))
                        .foregroundColor(pomodoro.isRunning ? .orange : .white.opacity(0.4))
                }
                .frame(width: 40, height: 40)
                
                // Digits
                VStack(alignment: .leading, spacing: 2) {
                    Text(pomodoro.formattedTime)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .monospacedDigit()
                    
                    // Controls
                    HStack(spacing: 8) {
                        Button(action: {
                            pomodoro.toggle()
                        }) {
                            HStack(spacing: 3) {
                                Image(systemName: pomodoro.isRunning ? "pause.fill" : "play.fill")
                                    .font(.system(size: 9))
                                Text(pomodoro.isRunning ? "Pause" : "Start")
                                    .font(.system(size: 10, weight: .semibold))
                            }
                            .foregroundColor(pomodoro.isRunning ? .white : .black)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 3)
                            .background(pomodoro.isRunning ? Color.white.opacity(0.2) : Color.green)
                            .clipShape(Capsule())
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        Button(action: {
                            pomodoro.reset()
                        }) {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.system(size: 10))
                                .foregroundColor(.white.opacity(0.6))
                                .frame(width: 20, height: 20)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
            .padding(.vertical, 4)
            
            // Presets Strip
            HStack(spacing: 6) {
                presetButton(name: "25m", minutes: 25, title: "Pomodoro")
                presetButton(name: "5m", minutes: 5, title: "Short Break")
                presetButton(name: "15m", minutes: 15, title: "Long Break")
            }
        }
    }
    
    private func presetButton(name: String, minutes: Int, title: String) -> some View {
        Button(action: {
            pomodoro.setPreset(name: title, minutes: minutes)
        }) {
            Text(name)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(pomodoro.totalDuration == minutes * 60 ? .white : .white.opacity(0.55))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
                .background(
                    pomodoro.totalDuration == minutes * 60
                    ? Color.white.opacity(0.18)
                    : Color.white.opacity(0.06)
                )
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .buttonStyle(PlainButtonStyle())
    }
}
