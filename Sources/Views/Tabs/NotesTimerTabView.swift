import SwiftUI

public struct NotesTimerTabView: View {
    @ObservedObject var reminders = ReminderService.shared
    @ObservedObject var pomodoro = PomodoroService.shared
    @ObservedObject var calendar = CalendarMeetingService.shared
    @State private var newNoteText: String = ""
    
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
    }
    
    // MARK: - Notes Column
    
    private var notesColumn: some View {
        VStack(spacing: 7) {
            // Header & Count (Non-redundant section title)
            HStack {
                HStack(spacing: 5) {
                    Image(systemName: "checklist")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.yellow)
                    Text("To-Do List")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                }
                
                Spacer()
                
                let remaining = reminders.pendingCount
                if remaining > 0 {
                    Text("\(remaining) pending")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white.opacity(0.55))
                } else if !reminders.notes.isEmpty {
                    Text("All done 🎉")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.green.opacity(0.85))
                }
                
                if reminders.completedCount > 0 {
                    Button(action: {
                        withAnimation {
                            reminders.clearCompleted()
                        }
                    }) {
                        Text("Clear done")
                            .font(.system(size: 9.5))
                            .foregroundColor(.white.opacity(0.4))
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help("Hapus tugas yang sudah selesai")
                }
            }
            
            // 📅 Real Calendar Meeting Banner (Only shown when actual meeting is scheduled)
            if let meeting = calendar.nextMeeting {
                meetingBanner(meeting)
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
                    if reminders.notes.isEmpty {
                        VStack(spacing: 5) {
                            Image(systemName: "checkmark.circle")
                                .font(.system(size: 15))
                                .foregroundColor(.white.opacity(0.2))
                            Text("No reminders")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.white.opacity(0.45))
                            Text("Type a task above and press Return")
                                .font(.system(size: 9.5))
                                .foregroundColor(.white.opacity(0.25))
                        }
                        .padding(.top, calendar.nextMeeting != nil ? 10 : 22)
                    } else {
                        ForEach(reminders.notes) { note in
                            noteRow(note)
                        }
                    }
                }
            }
            .frame(height: calendar.nextMeeting != nil ? 70 : 130)
        }
    }
    
    // MARK: - 📅 Meeting Banner
    private func meetingBanner(_ meeting: MeetingItem) -> some View {
        HStack(spacing: 8) {
            // Platform Icon
            ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.green.opacity(0.18))
                    .frame(width: 26, height: 26)
                
                Image(systemName: meeting.platform.iconName)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.green)
            }
            
            // Title & Countdown
            VStack(alignment: .leading, spacing: 2) {
                Text(meeting.title)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                HStack(spacing: 4) {
                    Text(meeting.formattedTimeRange)
                        .font(.system(size: 9.5))
                        .foregroundColor(.white.opacity(0.55))
                    
                    Text("•")
                        .font(.system(size: 9.5))
                        .foregroundColor(.white.opacity(0.35))
                    
                    Text(meeting.timeUntilString)
                        .font(.system(size: 9.5, weight: .semibold))
                        .foregroundColor(meeting.isOngoing ? .orange : .green)
                }
            }
            
            Spacer(minLength: 4)
            
            // 1-Click Join Button
            if meeting.meetingURL != nil {
                Button(action: {
                    calendar.joinMeeting(meeting)
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "video.fill")
                            .font(.system(size: 8.5, weight: .bold))
                        Text("Join")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .foregroundColor(.black)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(Color.green)
                    .clipShape(Capsule())
                    .shadow(color: Color.green.opacity(0.4), radius: 3, x: 0, y: 1)
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            // Dismiss / Selesai Button
            Button(action: {
                withAnimation {
                    calendar.dismissMeeting(meeting)
                }
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.white.opacity(0.45))
                    .padding(5)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Circle())
            }
            .buttonStyle(PlainButtonStyle())
            .help("Selesaikan / sembunyikan acara ini")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.green.opacity(0.25), lineWidth: 1)
                )
        )
    }
    
    private func noteRow(_ note: NoteItem) -> some View {
        HStack(spacing: 8) {
            // iOS Style Circular Checkbox
            Button(action: {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                    reminders.toggleNote(note)
                }
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
                withAnimation {
                    reminders.deleteNote(note)
                }
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
        withAnimation {
            reminders.addNote(text: trimmed)
        }
        newNoteText = ""
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
