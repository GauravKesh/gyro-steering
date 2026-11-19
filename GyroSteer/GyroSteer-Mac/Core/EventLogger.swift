//
//  EventLogger.swift
//  GyroSteer - macOS Receiver Core
//
//  Real-time diagnostic event logging with asynchronous background file persistence
//  at /tmp/gyrosteer.log and throttled @Published updates for SwiftUI DashboardView.
//

import Foundation

public final class EventLogger: ObservableObject, @unchecked Sendable {
    public static let shared = EventLogger()

    @Published public private(set) var recentLogs: [String] = []
    public let logFilePath = "/tmp/gyrosteer.log"

    private let lock = NSLock()
    private let maxEntries = 50
    private let ioQueue = DispatchQueue(label: "com.gyrosteer.eventlogger.io", qos: .utility)
    private var fileHandle: FileHandle?

    // UI Debouncing to prevent SwiftUI main-thread view invalidation storms
    private var pendingUILogs: [String] = []
    private var isUIDispatchPending = false

    private init() {
        let header = "=== GyroSteer Event Log Session [\(Date())] ===\n"
        try? header.write(toFile: logFilePath, atomically: true, encoding: .utf8)
        self.fileHandle = FileHandle(forWritingAtPath: logFilePath)
        self.fileHandle?.seekToEndOfFile()
    }

    deinit {
        try? fileHandle?.close()
    }

    public func log(_ message: String) {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        let timestamp = formatter.string(from: Date())
        let entry = "[\(timestamp)] \(message)"

        // Asynchronous non-blocking file I/O on background utility queue
        ioQueue.async { [weak self] in
            guard let self = self else { return }

            if let data = (entry + "\n").data(using: .utf8) {
                if self.fileHandle == nil {
                    self.fileHandle = FileHandle(forWritingAtPath: self.logFilePath)
                    self.fileHandle?.seekToEndOfFile()
                }
                self.fileHandle?.write(data)
            }

            // Buffer for throttled UI dispatch
            self.lock.lock()
            self.pendingUILogs.append(entry)
            let needsSchedule = !self.isUIDispatchPending
            if needsSchedule {
                self.isUIDispatchPending = true
            }
            self.lock.unlock()

            if needsSchedule {
                // Rate-limit UI list rendering to max 10Hz (every 100ms)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.10) { [weak self] in
                    self?.flushPendingLogsToUI()
                }
            }
        }
    }

    private func flushPendingLogsToUI() {
        lock.lock()
        let toFlush = pendingUILogs
        pendingUILogs.removeAll(keepingCapacity: true)
        isUIDispatchPending = false
        lock.unlock()

        guard !toFlush.isEmpty else { return }

        self.recentLogs.append(contentsOf: toFlush)
        if self.recentLogs.count > self.maxEntries {
            self.recentLogs.removeFirst(self.recentLogs.count - self.maxEntries)
        }
    }
}
