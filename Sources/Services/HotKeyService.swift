import Cocoa
import Carbon

public final class HotKeyService {
    public static let shared = HotKeyService()
    
    private var toggleHotKeyRef: EventHotKeyRef?
    private var queueHotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    
    private init() {}
    
    public func register() {
        let signature = OSType(0x4B4E5443) // 'KNTC'
        
        // 1. Register Option + Space (id: 1) -> Toggle Island
        let toggleID = EventHotKeyID(signature: signature, id: 1)
        let toggleStatus = RegisterEventHotKey(
            UInt32(kVK_Space),
            UInt32(optionKey),
            toggleID,
            GetApplicationEventTarget(),
            0,
            &toggleHotKeyRef
        )
        if toggleStatus != noErr {
            NSLog("[KeyNotch HotKey] Failed to register Option + Space: %d", toggleStatus)
        }
        
        // 2. Register Option + Shift + V (id: 2) -> Paste Next in Sequential Queue
        let queueID = EventHotKeyID(signature: signature, id: 2)
        let queueStatus = RegisterEventHotKey(
            UInt32(kVK_ANSI_V),
            UInt32(optionKey | shiftKey),
            queueID,
            GetApplicationEventTarget(),
            0,
            &queueHotKeyRef
        )
        if queueStatus != noErr {
            NSLog("[KeyNotch HotKey] Failed to register Option + Shift + V: %d", queueStatus)
        }
        
        // Install Event Handler for both hotkeys
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        
        let handlerStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            { (_, event, _) -> OSStatus in
                var hotKeyID = EventHotKeyID()
                let status = GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )
                
                if status == noErr {
                    DispatchQueue.main.async {
                        if hotKeyID.id == 1 {
                            IslandState.shared.toggleExpand()
                        } else if hotKeyID.id == 2 {
                            ClipboardService.shared.popNextInQueue()
                        }
                    }
                }
                return noErr
            },
            1,
            &eventType,
            nil,
            &eventHandler
        )
        
        if handlerStatus != noErr {
            NSLog("[KeyNotch HotKey] Failed to install event handler: %d", handlerStatus)
        }
    }
    
    public func unregister() {
        if let ref = toggleHotKeyRef {
            UnregisterEventHotKey(ref)
            toggleHotKeyRef = nil
        }
        if let ref = queueHotKeyRef {
            UnregisterEventHotKey(ref)
            queueHotKeyRef = nil
        }
        if let handler = eventHandler {
            RemoveEventHandler(handler)
            eventHandler = nil
        }
    }
    
    deinit {
        unregister()
    }
}
