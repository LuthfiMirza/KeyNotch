import Cocoa
import IOKit.pwr_mgt

public final class CaffeinateService: ObservableObject {
    public static let shared = CaffeinateService()
    
    @Published public var isCaffeinated: Bool = false
    private var assertionID: IOPMAssertionID = 0
    
    private init() {}
    
    public func toggle() {
        if isCaffeinated {
            deactivate()
        } else {
            activate()
        }
    }
    
    public func activate() {
        guard !isCaffeinated else { return }
        let reason = "KeyNotch Caffeinate Power Assertion" as CFString
        let success = IOPMAssertionCreateWithName(
            kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            reason,
            &assertionID
        )
        
        if success == kIOReturnSuccess {
            isCaffeinated = true
            IslandState.shared.triggerHUD(
                HUDPayload(
                    type: .custom,
                    title: "Caffeinate Active",
                    subtitle: "Sleep prevented",
                    iconName: "cup.and.saucer.fill",
                    isSuccess: true
                )
            )
        } else {
            NSLog("[KeyNotch Caffeinate] Failed to create power assertion: %d", success)
        }
    }
    
    public func deactivate() {
        guard isCaffeinated else { return }
        let success = IOPMAssertionRelease(assertionID)
        if success == kIOReturnSuccess {
            assertionID = 0
            isCaffeinated = false
            IslandState.shared.triggerHUD(
                HUDPayload(
                    type: .custom,
                    title: "Caffeinate Disabled",
                    subtitle: "Normal sleep restored",
                    iconName: "cup.and.saucer",
                    isSuccess: false
                )
            )
        }
    }
    
    public func cleanup() {
        if isCaffeinated {
            deactivate()
        }
    }
    
    deinit {
        cleanup()
    }
}
