import Cocoa
import CoreGraphics

public final class BrightnessService: ObservableObject {
    public static let shared = BrightnessService()
    
    @Published public var currentBrightness: Float = 0.8
    
    private typealias GetBrightnessFunc = @convention(c) (UInt32) -> Double
    private typealias SetBrightnessFunc = @convention(c) (UInt32, Double) -> Void
    
    private var getBrightnessFunc: GetBrightnessFunc?
    private var setBrightnessFunc: SetBrightnessFunc?
    
    private init() {
        setupCoreDisplay()
        readCurrentBrightness()
    }
    
    private func setupCoreDisplay() {
        if let handle = dlopen("/System/Library/Frameworks/CoreDisplay.framework/CoreDisplay", RTLD_NOW) {
            if let symGet = dlsym(handle, "CoreDisplay_Display_GetUserBrightness") {
                getBrightnessFunc = unsafeBitCast(symGet, to: GetBrightnessFunc.self)
            }
            if let symSet = dlsym(handle, "CoreDisplay_Display_SetUserBrightness") {
                setBrightnessFunc = unsafeBitCast(symSet, to: SetBrightnessFunc.self)
            }
        }
    }
    
    public func readCurrentBrightness() {
        guard let getFunc = getBrightnessFunc else { return }
        let val = Float(getFunc(CGMainDisplayID()))
        DispatchQueue.main.async {
            self.currentBrightness = max(0.0, min(1.0, val))
        }
    }
    
    public func setBrightness(_ value: Float) {
        let clamped = max(0.0, min(1.0, value))
        currentBrightness = clamped
        guard let setFunc = setBrightnessFunc else { return }
        setFunc(CGMainDisplayID(), Double(clamped))
    }
}
