# frozen_string_literal: true

require "json"
require "pathname"

module XCFrameworkDistribution
  ROOT = File.expand_path("..", __dir__)
  DISTRIBUTION_DIR = File.join(ROOT, "XCFrameworks")
  PREVIEWS_SUPPORT_XCFRAMEWORK = File.join(ROOT, "PreviewsSupport", "PreviewsSupport.xcframework")

  def self.distributed_xcframework_path(name)
    File.join(DISTRIBUTION_DIR, "#{name}.xcframework")
  end

  Platform = Struct.new(:sdk, :destination, :identifier, :display_identifier, keyword_init: true) do
    def matches?(library_identifier)
      identifier.is_a?(Regexp) ? library_identifier.match?(identifier) : library_identifier == identifier
    end

    def missing_identifier
      display_identifier || identifier
    end
  end
  Framework = Struct.new(
    :name,
    :category,
    :source_targets,
    :private_source_targets,
    :binary_dependencies,
    :compile_time_binary_dependencies,
    :external_packages,
    :target_dependencies,
    :public_header_targets,
    :linker_retained_dependencies,
    :expected_project_loads,
    :allowed_interface_imports,
    :requires_swift_module,
    keyword_init: true
  ) do
    def all_source_targets
      source_targets + private_source_targets
    end

    def all_binary_dependencies
      (binary_dependencies + compile_time_binary_dependencies).uniq
    end
  end

  PLATFORMS = [
    Platform.new(sdk: "iphonesimulator", destination: "generic/platform=iOS Simulator", identifier: "ios-arm64_x86_64-simulator"),
    Platform.new(sdk: "iphoneos", destination: "generic/platform=iOS", identifier: "ios-arm64"),
    Platform.new(sdk: "macosx", destination: "generic/platform=macOS", identifier: "macos-arm64_x86_64"),
    Platform.new(sdk: "watchsimulator", destination: "generic/platform=watchOS Simulator", identifier: "watchos-arm64_x86_64-simulator"),
    Platform.new(sdk: "watchos", destination: "generic/platform=watchOS", identifier: /^watchos-arm64_arm64_32/, display_identifier: "watchos-arm64_arm64_32*")
  ].freeze

  PROJECT_FRAMEWORK_NAMES = [
    "SnapshotSharedModels",
    "SnapshotPreviewsCore",
    "SnapshotPreferences",
    "PreviewGallery",
    "SnapshottingTests",
    "Snapshotting",
    "PreviewsSupport"
  ].freeze

  EXTERNAL_PACKAGES = {
    "FlyingFox" => ".package(url: \"https://github.com/swhitty/FlyingFox.git\", exact: \"0.16.0\")",
    "SimpleDebugger" => ".package(url: \"https://github.com/EmergeTools/SimpleDebugger.git\", exact: \"1.0.0\")"
  }.freeze

  UNEXPECTED_THIRD_PARTY_FRAMEWORKS = ["FlyingFox", "SimpleDebugger"].freeze
  ALLOWED_APPLE_RPATH_FRAMEWORKS = ["XCTest"].freeze
  ALLOWED_APPLE_RPATH_DYLIBS = ["libXCTestSwiftSupport.dylib"].freeze

  def self.project_load(name)
    "@rpath/#{name}.framework/#{name}"
  end

  FRAMEWORKS = [
    Framework.new(
      name: "SnapshotSharedModels",
      category: "required_support",
      source_targets: ["SnapshotSharedModels"],
      private_source_targets: [],
      binary_dependencies: [],
      compile_time_binary_dependencies: [],
      external_packages: [],
      target_dependencies: { "SnapshotSharedModels" => [] },
      public_header_targets: [],
      linker_retained_dependencies: [],
      expected_project_loads: [],
      allowed_interface_imports: [],
      requires_swift_module: true
    ),
    Framework.new(
      name: "SnapshotPreviewsCore",
      category: "required_support",
      source_targets: ["SnapshotPreviewsCore"],
      private_source_targets: [],
      binary_dependencies: ["SnapshotSharedModels", "PreviewsSupport"],
      compile_time_binary_dependencies: [],
      external_packages: [],
      target_dependencies: { "SnapshotPreviewsCore" => ["SnapshotSharedModels", "PreviewsSupport"] },
      public_header_targets: [],
      linker_retained_dependencies: ["SnapshotSharedModels", "PreviewsSupport"],
      expected_project_loads: [project_load("SnapshotSharedModels"), project_load("PreviewsSupport")],
      allowed_interface_imports: ["SnapshotSharedModels", "PreviewsSupport"],
      requires_swift_module: true
    ),
    Framework.new(
      name: "SnapshotPreferences",
      category: "user_facing_entry_point",
      source_targets: ["SnapshotPreferences"],
      private_source_targets: [],
      binary_dependencies: ["SnapshotSharedModels"],
      compile_time_binary_dependencies: [],
      external_packages: [],
      target_dependencies: { "SnapshotPreferences" => ["SnapshotSharedModels"] },
      public_header_targets: [],
      linker_retained_dependencies: ["SnapshotSharedModels"],
      expected_project_loads: [project_load("SnapshotSharedModels")],
      allowed_interface_imports: ["SnapshotSharedModels"],
      requires_swift_module: true
    ),
    Framework.new(
      name: "PreviewGallery",
      category: "user_facing_entry_point",
      source_targets: ["PreviewGallery"],
      private_source_targets: [],
      binary_dependencies: ["SnapshotPreviewsCore", "SnapshotPreferences"],
      compile_time_binary_dependencies: ["SnapshotSharedModels", "PreviewsSupport"],
      external_packages: [],
      target_dependencies: { "PreviewGallery" => ["SnapshotPreviewsCore", "SnapshotPreferences", "SnapshotSharedModels", "PreviewsSupport"] },
      public_header_targets: [],
      linker_retained_dependencies: ["SnapshotPreviewsCore", "SnapshotPreferences", "SnapshotSharedModels", "PreviewsSupport"],
      expected_project_loads: [project_load("SnapshotPreviewsCore"), project_load("SnapshotPreferences"), project_load("SnapshotSharedModels"), project_load("PreviewsSupport")],
      allowed_interface_imports: ["SnapshotPreviewsCore", "SnapshotPreferences"],
      requires_swift_module: true
    ),
    Framework.new(
      name: "SnapshottingTests",
      category: "user_facing_entry_point",
      source_targets: ["SnapshottingTests"],
      private_source_targets: ["SnapshottingTestsObjc"],
      binary_dependencies: ["SnapshotPreviewsCore", "SnapshotSharedModels"],
      compile_time_binary_dependencies: ["PreviewsSupport"],
      external_packages: ["SimpleDebugger"],
      target_dependencies: {
        "SnapshottingTests" => ["SnapshotPreviewsCore", "SnapshottingTestsObjc", "SnapshotSharedModels", "PreviewsSupport"],
        "SnapshottingTestsObjc" => [".product(name: \"SimpleDebugger\", package: \"SimpleDebugger\", condition: .when(platforms: [.iOS, .macOS, .macCatalyst]))"]
      },
      public_header_targets: ["SnapshottingTestsObjc"],
      linker_retained_dependencies: ["SnapshotPreviewsCore", "SnapshotSharedModels", "PreviewsSupport"],
      expected_project_loads: [project_load("SnapshotPreviewsCore"), project_load("SnapshotSharedModels"), project_load("PreviewsSupport")],
      allowed_interface_imports: ["SnapshotSharedModels", "SnapshotPreviewsCore"],
      requires_swift_module: true
    ),
    Framework.new(
      name: "Snapshotting",
      category: "compatibility_runtime",
      source_targets: ["Snapshotting"],
      private_source_targets: ["SnapshottingSwift"],
      binary_dependencies: ["SnapshotPreviewsCore"],
      compile_time_binary_dependencies: ["SnapshotSharedModels", "PreviewsSupport"],
      external_packages: ["FlyingFox"],
      target_dependencies: {
        "Snapshotting" => ["SnapshottingSwift", "SnapshotPreviewsCore", "SnapshotSharedModels", "PreviewsSupport"],
        "SnapshottingSwift" => ["SnapshotPreviewsCore", "SnapshotSharedModels", "PreviewsSupport", ".product(name: \"FlyingFox\", package: \"FlyingFox\")"]
      },
      public_header_targets: ["Snapshotting"],
      linker_retained_dependencies: ["SnapshotPreviewsCore", "SnapshotSharedModels", "PreviewsSupport"],
      expected_project_loads: [project_load("SnapshotPreviewsCore"), project_load("SnapshotSharedModels"), project_load("PreviewsSupport")],
      allowed_interface_imports: [],
      requires_swift_module: false
    )
  ].freeze

  FRAMEWORK_BY_NAME = FRAMEWORKS.to_h { |framework| [framework.name, framework] }.freeze

  def self.available_libraries(xcframework_path)
    info_path = File.join(xcframework_path, "Info.plist")
    stdout = IO.popen(["plutil", "-convert", "json", "-o", "-", info_path], &:read)
    raise "Failed to read #{info_path}" unless $?.success?

    JSON.parse(stdout).fetch("AvailableLibraries")
  end

  def self.required_platform_missing_identifiers(identifiers)
    PLATFORMS.each_with_object([]) do |platform, missing|
      matched = identifiers.any? { |identifier| platform.matches?(identifier) }
      missing << platform.missing_identifier unless matched
    end
  end
end
