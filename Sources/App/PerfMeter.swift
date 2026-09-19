// Live cost readout, the way a game shows frames per second: this app claims to
// be cheap, so it shows what it is actually spending. One sample per second.
import Darwin
import Foundation
import SwiftUI

final class PerfMeter: ObservableObject {
    @Published var cpu: Double = 0        // percent of one core
    @Published var memMB: Double = 0      // physical footprint
    @Published var history: [Double] = Array(repeating: 0, count: 40)

    private var timer: DispatchSourceTimer?
    private var lastCPUSeconds: Double = 0
    private var lastSample: CFAbsoluteTime = 0

    func start() {
        guard timer == nil else { return }
        lastCPUSeconds = Self.cpuSeconds()
        lastSample = CFAbsoluteTimeGetCurrent()
        let t = DispatchSource.makeTimerSource(queue: .main)
        t.schedule(deadline: .now() + 1, repeating: 1, leeway: .milliseconds(400))
        t.setEventHandler { [weak self] in self?.sample() }
        t.resume()
        timer = t
    }

    func stop() {
        timer?.cancel()
        timer = nil
    }

    private func sample() {
        let now = CFAbsoluteTimeGetCurrent()
        let cpuSeconds = Self.cpuSeconds()
        let elapsed = max(now - lastSample, 0.001)
        let used = max(cpuSeconds - lastCPUSeconds, 0)
        lastSample = now
        lastCPUSeconds = cpuSeconds
        let percent = min(used / elapsed * 100, 800)
        cpu = percent
        memMB = Self.footprintMB()
        history.removeFirst()
        history.append(percent)
    }

    /// User + system CPU consumed by this process, in seconds.
    private static func cpuSeconds() -> Double {
        var info = rusage_info_current()
        let ok = withUnsafeMutablePointer(to: &info) { ptr -> Int32 in
            ptr.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) { rebound in
                proc_pid_rusage(getpid(), RUSAGE_INFO_CURRENT, rebound)
            }
        }
        guard ok == 0 else { return 0 }
        return Double(info.ri_user_time + info.ri_system_time) / 1_000_000_000
    }

    private static func footprintMB() -> Double {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<integer_t>.size)
        let kerr = withUnsafeMutablePointer(to: &info) { ptr -> kern_return_t in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { rebound in
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), rebound, &count)
            }
        }
        guard kerr == KERN_SUCCESS else { return 0 }
        return Double(info.phys_footprint) / 1_048_576
    }
}

struct PerfOverlay: View {
    @ObservedObject var meter: PerfMeter
    let renderMS: Double

    private var tint: Color {
        if meter.cpu < 6 { return Palette.tealC }
        if meter.cpu < 30 { return Palette.brassC }
        return Color(nsColor: NSColor.systemRed)
    }

    var body: some View {
        HStack(spacing: 9) {
            Sparkline(values: meter.history)
                .stroke(tint, style: StrokeStyle(lineWidth: 1.2, lineJoin: .round))
                .frame(width: 46, height: 13)
            readout(String(format: "%.1f%%", meter.cpu), "cpu", tint)
            readout(String(format: "%.0f MB", meter.memMB), "mem", Palette.mutedC)
            readout(String(format: "%.1f ms", renderMS), "draw", Palette.mutedC)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(.thinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .strokeBorder(Palette.borderC, lineWidth: 1)
                }
        }
        .help("This process: processor time per second, memory footprint, and the time the last preview redraw took. The WebKit renderer runs in its own helper process and is not counted here.")
        .allowsHitTesting(false)
        .fixedSize()
    }

    private func readout(_ value: String, _ label: String, _ color: Color) -> some View {
        HStack(spacing: 4) {
            Text(value)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .monospacedDigit()
                .foregroundColor(color)
            Text(label)
                .font(.system(size: 8, weight: .semibold))
                .tracking(0.5)
                .foregroundColor(Palette.mutedC.opacity(0.75))
        }
    }
}

private struct Sparkline: Shape {
    let values: [Double]

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard values.count > 1 else { return path }
        let peak = max(values.max() ?? 1, 8)
        let step = rect.width / CGFloat(values.count - 1)
        for (i, v) in values.enumerated() {
            let y = rect.maxY - CGFloat(v / peak) * rect.height
            let point = CGPoint(x: rect.minX + CGFloat(i) * step, y: y)
            if i == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        return path
    }
}
