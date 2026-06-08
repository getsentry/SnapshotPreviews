struct SnapshotPreviewDeviceFilter {
  static func shouldInclude(
    discoveredPreview: DiscoveredPreview,
    index: Int,
    currentDestinationDeviceName: String?
  ) -> Bool {
    let requestedDevice = discoveredPreview.devices.indices.contains(index) ? discoveredPreview.devices[index] : nil
    return shouldInclude(requestedDeviceName: requestedDevice, currentDestinationDeviceName: currentDestinationDeviceName)
  }

  static func shouldInclude(
    requestedDeviceName: String?,
    currentDestinationDeviceName: String?
  ) -> Bool {
    guard let currentDestinationDeviceName else {
      return true
    }

    guard let requestedDeviceName, !requestedDeviceName.isEmpty else {
      return true
    }

    return requestedDeviceName == currentDestinationDeviceName
  }
}
