import SwiftUI
import PreviewsSupport

public struct Preview: Identifiable {
  init<P: SwiftUI.PreviewProvider>(preview: _Preview, type: P.Type) {
    previewId = "\(preview.id)"
    index = preview.id
    orientation = preview.interfaceOrientation
    displayName = preview.displayName
    device = preview.device
    layout = preview.layout
    _modifiers = []
    _view = {
      ViewSelectorTree(SnapshotViewModel(index: preview.id)) {
        P.previews
      }
    }
  }

#if compiler(>=5.9)
  @available(iOS 17.0, macOS 14.0, watchOS 10.0, tvOS 17.0, *)
  init?(preview: DeveloperToolsSupport.Preview) {
    previewId = "0"
    var orientation: InterfaceOrientation = .portrait
    device = nil
    index = 0
    let preview = Mirror(reflecting: preview)
    let traits = preview.descendant("traits")! as! [Any]
    var layout = PreviewLayout.device
    var modifiers: [Any] = []
    for t in traits {
      if let value = Mirror(reflecting: t).descendant("value") {
        if let value = value as? PreviewLayout {
          layout = value
        } else if #available(iOS 18.0, macOS 15.0, watchOS 11.0, tvOS 18.0, *),
               let traitModifiers = value as? [any PreviewModifier] {
          modifiers += traitModifiers
        } else if String(describing: value).hasSuffix(".portraitUpsideDown") {
          orientation = .portraitUpsideDown
        } else if String(describing: value).hasSuffix(".landscapeLeft") {
          orientation = .landscapeLeft
        } else if String(describing: value).hasSuffix(".landscapeRight") {
          orientation = .landscapeRight
        }
      }
    }
    self._modifiers = modifiers
    self.orientation = orientation
    self.layout = layout
    displayName = preview.descendant("displayName") as? String
    guard let source = preview.descendant("source") ?? preview.descendant("dataSource", "preview") else {
      assertionFailure("Preview \(preview) missing source, found: \(preview.children)")
      return nil
    }
    let _view: @MainActor () -> any View
    if let source = source as? MakeViewProvider {
      _view = {
        return source.makeView()
      }
    } else {
      #if canImport(UIKit) && !os(watchOS)
      if let source = source as? MakeUIViewProvider {
        _view = {
          return UIViewWrapper(source.makeView)
        }
      } else if let source = source as? MakeViewControllerProvider {
        _view = {
          return UIViewControllerWrapper(source.makeViewController)
        }
      } else {
        print("Preview \(preview) (\(displayName ?? "no display name")) did not have matching source type")
        return nil
      }
      #else
      print("Preview \(preview) (\(displayName ?? "no display name")) did not have matching source type")
      return nil
      #endif
    }

    self._view = _view
  }
#endif

  public let id = UUID()
  public let previewId: String
  public let orientation: InterfaceOrientation
  public let displayName: String?
  public let index: Int
  public let device: PreviewDevice?
  public let layout: PreviewLayout

  // we can't store `[any PreviewModifier]` because it's unavailable before iOS 18 et al
  private let _modifiers: [Any]
  @available(iOS 18.0, macOS 15.0, watchOS 11.0, tvOS 18.0, *)
  public var modifiers: [any PreviewModifier] {
    _modifiers as? [any PreviewModifier] ?? []
  }

  private let _view: @MainActor () -> any View
  @MainActor public func view() -> any View {
    _view()
  }
}

// Wraps PreviewProvider or PreviewRegistry
public struct PreviewType: Hashable, Identifiable {
  init<A: PreviewProvider>(typeName: String, previewProvider: A.Type) {
    self.typeName = typeName
    self.fileID = nil
    self.line = nil
    self.previews = A._allPreviews.map { Preview(preview: $0, type: A.self) }
    self.platform = A.platform
  }

#if compiler(>=5.9)
  @available(iOS 17.0, macOS 14.0, watchOS 10.0, tvOS 17.0, *)
  @MainActor
  init?<A: PreviewRegistry>(typeName: String, registry: A.Type) {
    self.typeName = typeName
    self.fileID = A.fileID
    self.line = A.line
    guard let internalPreview = try? A.makePreview(), let preview = Preview(preview: internalPreview)  else {
      return nil
    }
    self.previews = [preview]
    self.platform = nil
  }
#endif

  public var module: String {
    String(typeName.split(separator: ".").first!)
  }

  public func hash(into hasher: inout Hasher) {
    hasher.combine(typeName)
  }

  public static func ==(lhs: Self, rhs: Self) -> Bool {
    lhs.typeName == rhs.typeName
  }

  public var displayName: String {
    if let fileID = fileID {
      return String(fileID.split(separator: "/").last!.split(separator: ".").first!).splittingHumanReadableName.joined(separator: " ")
    }
    let withoutModule = typeName
      .split(separator: ".")
      .dropFirst()
      .joined(separator: ".")
    let components = withoutModule.splittingHumanReadableName
    if components.last == "Previews" {
      return components.dropLast().joined(separator: " ")
    }
    return components.joined(separator: " ")
  }

  public let id = UUID()
  public let fileID: String?
  public let line: Int?
  public let typeName: String
  public var previews: [Preview]
  public let platform: PreviewPlatform?
}

// The enum provides a namespace
public enum FindPreviews {
  static func moduleName(typeName: String) -> String {
    String(typeName.split(separator: ".", maxSplits: 1).first ?? "")
  }

  static func shouldIncludeModule(typeName: String, includedModulesSet: Set<String>?, excludedModulesSet: Set<String>?) -> Bool {
    let module = moduleName(typeName: typeName)

    if let excludedModulesSet, excludedModulesSet.contains(module) {
      return false
    }

    guard let includedModulesSet else {
      return true
    }

    return includedModulesSet.contains(module)
  }

  @available(iOS 16.0, macOS 13.0, tvOS 16.0, *)
  private static func shouldInclude(name: String, excludedPreviewsSet: Set<String>?, previewsSet: Set<String>?) -> Bool {
    if let excludedPreviewsSet {
      for excludedPreview in excludedPreviewsSet {
        do {
          let regex = try Regex(excludedPreview)
          if name.firstMatch(of: regex) != nil {
            return false
          }
        } catch {
          print("Error trying to unwrap regex for excludedSnapshotPreview (\(excludedPreview)): \(error)")
        }
      }
    }

    guard let previewsSet else { return true }
    for preview in previewsSet {
      do {
        let regex = try Regex(preview)
        if name.firstMatch(of: regex) != nil {
          return true
        }
      } catch {
        print("Error trying to unwrap regex for snapshotPreview (\(preview)): \(error)")
      }
    }

    return false
  }

  @MainActor
  public static func findPreviews(
    included: [String]?,
    excluded: [String]?,
    includedModules: [String]? = nil,
    excludedModules: [String]? = nil
  ) -> [PreviewType] {
    let previewsSet = included.map { Set($0) }
    let excludedPreviewsSet = excluded.map { Set($0) }
    let includedModulesSet = includedModules.map { Set($0) }
    let excludedModulesSet = excludedModules.map { Set($0) }

    let previewTypes = findPreviews { name, proto in
      if !shouldIncludeModule(typeName: name, includedModulesSet: includedModulesSet, excludedModulesSet: excludedModulesSet) {
        return false
      }

      guard #available(iOS 16.0, macOS 13.0, tvOS 16.0, *) else { return true }
      guard proto == "PreviewProvider" else { return true }

      return shouldInclude(name: name, excludedPreviewsSet: excludedPreviewsSet, previewsSet: previewsSet)
    }
    return previewTypes.compactMap { preview -> PreviewType? in
      if let fileId = preview.fileID, #available(iOS 16.0, macOS 13.0, tvOS 16.0, *) {
        var name = fileId
        if let displayName = preview.previews[0].displayName {
          name = "\(fileId):\(displayName)"
        }
        if !shouldInclude(name: name, excludedPreviewsSet: excludedPreviewsSet, previewsSet: previewsSet) {
          return nil
        }
      }
      return preview
    }
  }

  @MainActor
  public static func findPreviews(
    shouldInclude: (String, String) -> Bool = { _, _ in true },
    willAccess: (String) -> Void = { _ in }) -> [PreviewType]
  {
    return getPreviewTypes()
      .filter { shouldInclude($0.name, $0.proto) }
      .compactMap { conformance -> PreviewType? in
        let (name, accessor, proto) = conformance
        willAccess(name)
        switch proto {
        case "PreviewProvider":
          let previewProvider = unsafeBitCast(accessor(), to: Any.Type.self) as! any PreviewProvider.Type
          return PreviewType(typeName: name, previewProvider: previewProvider)
        case "PreviewRegistry":
    #if compiler(>=5.9)
          if #available(iOS 17.0, macOS 14.0, watchOS 10.0, tvOS 17.0, *) {
            let previewRegistry = unsafeBitCast(accessor(), to: Any.Type.self) as! any PreviewRegistry.Type
            return PreviewType(typeName: name, registry: previewRegistry)
          }
    #endif
          return nil
        default:
          return nil
        }
    }
  }
}
