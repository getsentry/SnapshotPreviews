import SnapshottingTests

final class MultiModuleDemoSnapshotTests: SnapshotTest {
}

final class MultiModuleDemoSnapshotSingleModuleAllowTests: SnapshotTest {
  override class func snapshotPreviewModules() -> [String]? {
    return ["ModuleA"]
  }
}

final class MultiModuleDemoSnapshotMultipleModuleAllowTests: SnapshotTest {
  override class func snapshotPreviewModules() -> [String]? {
    return ["ModuleB", "ModuleC"]
  }
}

final class MultiModuleDemoSnapshotSingleModuleExcludeTests: SnapshotTest {
  override class func excludedSnapshotPreviewModules() -> [String]? {
    return ["ModuleA"]
  }
}

final class MultiModuleDemoSnapshotMultipleModuleExcludeTests: SnapshotTest {
  override class func excludedSnapshotPreviewModules() -> [String]? {
    return ["ModuleB", "ModuleC"]
  }
}
