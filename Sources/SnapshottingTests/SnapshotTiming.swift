//
//  SnapshotTiming.swift
//
//  Opt-in diagnostic instrumentation for measuring where snapshot-generation
//  time actually goes in CI. Entirely inert unless the SNAPSHOT_TIMING
//  environment variable is set, so it is safe to ship on a diagnostic branch.
//
//  When enabled it records:
//    - a per-preview row (render wall time, status, whether a11y ran), and
//    - coarse phase marks (discovery, drain) plus the derived pre/render/post
//      breakdown,
//  then writes `_snapshot_timings.csv` + `_snapshot_timings_summary.txt` to
//  SNAPSHOT_TIMING_DIR (falling back to SNAPSHOTS_EXPORT_DIR). Every row is also
//  emitted via NSLog so it shows up in raw xcodebuild output.
//
//  Pass the flags into the simulator test process with the TEST_RUNNER_ prefix,
//  e.g. TEST_RUNNER_SNAPSHOT_TIMING=1.
//

import Foundation

final class SnapshotTiming {

  static let shared = SnapshotTiming()

  static var isEnabled: Bool {
    ProcessInfo.processInfo.environment["SNAPSHOT_TIMING"] != nil
  }

  private struct Row {
    let label: String
    let ms: Double
    let status: String
    let a11y: Bool
    let startNs: UInt64
    let endNs: UInt64
  }

  private let lock = NSLock()
  private var rows: [Row] = []
  private var marks: [(name: String, ns: UInt64)] = []
  private var flushed = false

  static func nowNs() -> UInt64 {
    clock_gettime_nsec_np(CLOCK_MONOTONIC_RAW)
  }

  /// Records a coarse phase boundary (e.g. "discovery_start", "drain_end").
  static func mark(_ name: String) {
    guard isEnabled else { return }
    let ns = nowNs()
    shared.lock.lock()
    shared.marks.append((name, ns))
    shared.lock.unlock()
  }

  /// Records one preview's render wall time.
  static func record(label: String, startNs: UInt64, endNs: UInt64, status: String, a11y: Bool) {
    guard isEnabled else { return }
    let ms = Double(endNs &- startNs) / 1_000_000
    shared.lock.lock()
    shared.rows.append(Row(label: label, ms: ms, status: status, a11y: a11y, startNs: startNs, endNs: endNs))
    shared.lock.unlock()
    NSLog("%@", "SNAPSHOT_TIMING\t\(String(format: "%.1f", ms))\t\(status)\t\(a11y ? "a11y" : "-")\t\(label)")
  }

  /// Writes the CSV + summary. Idempotent; safe to call more than once.
  static func flush() {
    guard isEnabled else { return }
    shared.flushImpl()
  }

  private func flushImpl() {
    lock.lock()
    guard !flushed else { lock.unlock(); return }
    flushed = true
    let rows = self.rows
    let marks = self.marks
    lock.unlock()

    let env = ProcessInfo.processInfo.environment
    let device = env["SIMULATOR_DEVICE_NAME"] ?? env["SIMULATOR_MODEL_IDENTIFIER"] ?? "unknown"

    func markNs(_ name: String) -> UInt64? { marks.first(where: { $0.name == name })?.ns }
    func spanMs(_ a: String, _ b: String) -> Double? {
      guard let x = markNs(a), let y = markNs(b) else { return nil }
      return Double(y &- x) / 1_000_000
    }

    let renderTotalMs = rows.reduce(0) { $0 + $1.ms }
    let renderWallMs: Double = {
      guard let first = rows.map(\.startNs).min(), let last = rows.map(\.endNs).max() else { return 0 }
      return Double(last &- first) / 1_000_000
    }()
    let discoveryMs = spanMs("discovery_start", "discovery_end")
    let drainMs = spanMs("drain_start", "drain_end")
    let a11yRows = rows.filter { $0.a11y }
    let a11yMs = a11yRows.reduce(0) { $0 + $1.ms }

    func fmt(_ v: Double?) -> String { v.map { String(format: "%.0f", $0) } ?? "n/a" }

    var summary = ""
    summary += "device                : \(device)\n"
    summary += "previews              : \(rows.count)\n"
    summary += "discovery             : \(fmt(discoveryMs)) ms\n"
    summary += "render (sum)          : \(String(format: "%.0f", renderTotalMs)) ms\n"
    summary += "render (wall span)    : \(String(format: "%.0f", renderWallMs)) ms\n"
    summary += "drain (png writes)    : \(fmt(drainMs)) ms\n"
    if !rows.isEmpty {
      summary += "render mean / max     : \(String(format: "%.0f", renderTotalMs / Double(rows.count))) / \(String(format: "%.0f", rows.map(\.ms).max() ?? 0)) ms\n"
    }
    summary += "a11y previews         : \(a11yRows.count) (\(String(format: "%.0f", a11yMs)) ms, \(renderTotalMs > 0 ? Int(a11yMs / renderTotalMs * 100) : 0)% of render)\n"
    let statuses = Dictionary(grouping: rows, by: { $0.status }).mapValues(\.count)
    summary += "status                : \(statuses)\n"

    NSLog("%@", "SNAPSHOT_TIMING_SUMMARY\n\(summary)")

    guard let dir = outputDirectory(env: env) else { return }
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

    var csv = "label\trender_ms\tstatus\ta11y\n"
    for r in rows.sorted(by: { $0.ms > $1.ms }) {
      csv += "\(r.label)\t\(String(format: "%.1f", r.ms))\t\(r.status)\t\(r.a11y ? "a11y" : "-")\n"
    }
    try? csv.write(to: dir.appendingPathComponent("_snapshot_timings.csv"), atomically: true, encoding: .utf8)
    try? summary.write(to: dir.appendingPathComponent("_snapshot_timings_summary.txt"), atomically: true, encoding: .utf8)
  }

  private func outputDirectory(env: [String: String]) -> URL? {
    let raw = env["SNAPSHOT_TIMING_DIR"] ?? env["SNAPSHOTS_EXPORT_DIR"]
    guard let raw else { return nil }
    let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return nil }
    if trimmed.hasPrefix("/") {
      return URL(fileURLWithPath: trimmed, isDirectory: true).standardizedFileURL
    }
    return URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
      .appendingPathComponent(trimmed, isDirectory: true)
      .standardizedFileURL
  }
}
