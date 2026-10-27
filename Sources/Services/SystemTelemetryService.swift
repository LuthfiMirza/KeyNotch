import Cocoa
import Darwin
import Combine

public final class SystemTelemetryService: ObservableObject {
    public static let shared = SystemTelemetryService()
    
    // Published Telemetry Metrics
    @Published public var cpuUsagePercent: Double = 0.0
    @Published public var ramUsageString: String = "-- / -- GB"
    @Published public var ramUsagePercent: Double = 0.0
    @Published public var usedRAMGB: Double = 0.0
    @Published public var totalRAMGB: Double = 0.0
    
    private var prevCpuTicks: (user: UInt32, sys: UInt32, idle: UInt32, nice: UInt32)?
    private var telemetryTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        // Enforce 0.0% CPU: Run telemetry ONLY when the island is expanded
        IslandState.shared.$isExpanded
            .receive(on: RunLoop.main)
            .sink { [weak self] expanded in
                if expanded {
                    self?.startTelemetry()
                } else {
                    self?.stopTelemetry()
                }
            }
            .store(in: &cancellables)
    }
    
    public func startTelemetry() {
        stopTelemetry()
        updateMetrics()
        // 2-second polling interval while expanded
        telemetryTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.updateMetrics()
        }
    }
    
    public func stopTelemetry() {
        telemetryTimer?.invalidate()
        telemetryTimer = nil
        prevCpuTicks = nil
    }
    
    public func updateMetrics() {
        updateCPUMetrics()
        updateRAMMetrics()
    }
    
    // MARK: - Mach Kernel CPU Load Info
    
    private func updateCPUMetrics() {
        var hostCpuLoadInfo = host_cpu_load_info()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info>.size / MemoryLayout<integer_t>.size)
        
        let result = withUnsafeMutablePointer(to: &hostCpuLoadInfo) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count)
            }
        }
        
        guard result == KERN_SUCCESS else { return }
        
        let user = hostCpuLoadInfo.cpu_ticks.0
        let sys = hostCpuLoadInfo.cpu_ticks.1
        let idle = hostCpuLoadInfo.cpu_ticks.2
        let nice = hostCpuLoadInfo.cpu_ticks.3
        
        if let prev = prevCpuTicks {
            let deltaUser = user >= prev.user ? user - prev.user : 0
            let deltaSys = sys >= prev.sys ? sys - prev.sys : 0
            let deltaIdle = idle >= prev.idle ? idle - prev.idle : 0
            let deltaNice = nice >= prev.nice ? nice - prev.nice : 0
            
            let totalTicks = deltaUser + deltaSys + deltaIdle + deltaNice
            if totalTicks > 0 {
                let activeTicks = deltaUser + deltaSys + deltaNice
                let cpuPercent = (Double(activeTicks) / Double(totalTicks)) * 100.0
                DispatchQueue.main.async {
                    self.cpuUsagePercent = min(100.0, max(0.0, cpuPercent))
                }
            }
        }
        
        prevCpuTicks = (user: user, sys: sys, idle: idle, nice: nice)
    }
    
    // MARK: - Mach Kernel Physical RAM Metrics
    
    private func updateRAMMetrics() {
        var vmStats = vm_statistics64()
        var vmCount = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)
        
        let result = withUnsafeMutablePointer(to: &vmStats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(vmCount)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &vmCount)
            }
        }
        
        guard result == KERN_SUCCESS else { return }
        
        let pageSize = UInt64(vm_kernel_page_size)
        let active = UInt64(vmStats.active_count) * pageSize
        let wired = UInt64(vmStats.wire_count) * pageSize
        let compressed = UInt64(vmStats.compressor_page_count) * pageSize
        
        let usedBytes = active + wired + compressed
        let totalBytes = ProcessInfo.processInfo.physicalMemory
        
        let usedGB = Double(usedBytes) / 1_073_741_824.0
        let totalGB = Double(totalBytes) / 1_073_741_824.0
        let ramPercent = (usedGB / totalGB) * 100.0
        
        DispatchQueue.main.async {
            self.usedRAMGB = usedGB
            self.totalRAMGB = totalGB
            self.ramUsagePercent = min(100.0, max(0.0, ramPercent))
            self.ramUsageString = String(format: "%.1f / %.1f GB (%d%%)", usedGB, totalGB, Int(ramPercent))
        }
    }
}
