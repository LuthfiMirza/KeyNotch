import Cocoa
import Carbon

public final class HotKeyService {
    public static let shared = HotKeyService()
    
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    
    private init() {}
    
    public func register() {
        // HotKey identifier ('KNTC', id 1)
        let signature = OSType(0x4B4E5443)
        let hotKeyID = EventHotKeyID(signature: signature, id: 1)
        
        // Register Option + Space (kVK_Space = 49)
        let registerStatus = RegisterEventHotKey(
            UInt32(kVK_Space),
            UInt32(optionKey),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
        
        if registerStatus != noErr {
            NSLog("[KeyNotch HotKey] Failed to register Option + Space: %d", registerStatus)
            return
        }
        
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        
        let handlerStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            { (_, _, _) -> OSStatus in
                DispatchQueue.main.async {
                    IslandState.shared.toggleExpand()
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
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
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
