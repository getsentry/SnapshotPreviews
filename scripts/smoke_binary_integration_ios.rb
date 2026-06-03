#!/usr/bin/env ruby
# frozen_string_literal: true

require "digest"
require "fileutils"
require "json"
require "open3"
require "shellwords"

ROOT = File.expand_path("..", __dir__)
BUILD_ROOT = File.expand_path(ENV.fetch("BINARY_SMOKE_BUILD_DIR", "build/binary-integration-smoke/ios"), ROOT)
PROJECT_NAME = "BinarySmoke"
APP_TARGET = "BinarySmokeApp"
TEST_TARGET = "BinarySmokeTests"
EXPORT_DIR = File.join(BUILD_ROOT, "snapshot-export")
DERIVED_DATA_DIR = File.join(BUILD_ROOT, "DerivedData")
RESULT_BUNDLE_PATH = File.join(BUILD_ROOT, "BinarySmoke.xcresult")
FRAMEWORK_PATHS = {
  "PreviewGallery" => File.join(ROOT, "XCFrameworks", "PreviewGallery.xcframework"),
  "PreviewsSupport" => File.join(ROOT, "XCFrameworks", "PreviewsSupport.xcframework"),
  "SnapshotPreferences" => File.join(ROOT, "XCFrameworks", "SnapshotPreferences.xcframework"),
  "SnapshotPreviewsCore" => File.join(ROOT, "XCFrameworks", "SnapshotPreviewsCore.xcframework"),
  "SnapshotSharedModels" => File.join(ROOT, "XCFrameworks", "SnapshotSharedModels.xcframework"),
  "SnapshottingTests" => File.join(ROOT, "XCFrameworks", "SnapshottingTests.xcframework")
}.freeze
APP_FRAMEWORKS = %w[PreviewGallery SnapshotPreviewsCore SnapshotPreferences SnapshotSharedModels PreviewsSupport].freeze
TEST_FRAMEWORKS = %w[SnapshottingTests SnapshotPreviewsCore SnapshotSharedModels PreviewsSupport].freeze
FRAMEWORKS = (APP_FRAMEWORKS + TEST_FRAMEWORKS).uniq.freeze

# Follow-up: add equivalent generated-project smokes for macOS and watchOS before release publication.

Ref = Struct.new(:value)

class SmokeProject
  def initialize
    @ids = {}
    @objects = {}
  end

  def write
    FileUtils.rm_rf(BUILD_ROOT)
    FileUtils.mkdir_p([project_dir, workspace_dir, scheme_dir, app_dir, test_dir, EXPORT_DIR])
    File.write(File.join(app_dir, "BinarySmokeApp.swift"), app_source)
    File.write(File.join(test_dir, "BinarySmokeTests.swift"), test_source)
    build_objects
    File.write(File.join(project_dir, "project.pbxproj"), render_project)
    File.write(File.join(workspace_dir, "contents.xcworkspacedata"), workspace)
    File.write(File.join(scheme_dir, "#{PROJECT_NAME}.xcscheme"), scheme)
  end

  def project_path
    project_dir
  end

  private

  def project_dir
    File.join(BUILD_ROOT, "#{PROJECT_NAME}.xcodeproj")
  end

  def scheme_dir
    File.join(project_dir, "xcshareddata", "xcschemes")
  end

  def workspace_dir
    File.join(project_dir, "project.xcworkspace")
  end

  def app_dir
    File.join(BUILD_ROOT, APP_TARGET)
  end

  def test_dir
    File.join(BUILD_ROOT, TEST_TARGET)
  end

  def id(label)
    @ids[label] ||= "A#{Digest::MD5.hexdigest(label).upcase[0, 23]}"
  end

  def ref(label)
    Ref.new(id(label))
  end

  def add(label, isa, attrs = {})
    @objects[id(label)] = attrs.merge("isa" => isa)
    ref(label)
  end

  def build_objects
    app_source_file = add("app_source_file", "PBXFileReference", "lastKnownFileType" => "sourcecode.swift", "path" => "BinarySmokeApp.swift", "sourceTree" => "<group>")
    test_source_file = add("test_source_file", "PBXFileReference", "lastKnownFileType" => "sourcecode.swift", "path" => "BinarySmokeTests.swift", "sourceTree" => "<group>")
    app_product = add("app_product", "PBXFileReference", "explicitFileType" => "wrapper.application", "includeInIndex" => 0, "path" => "#{APP_TARGET}.app", "sourceTree" => "BUILT_PRODUCTS_DIR")
    test_product = add("test_product", "PBXFileReference", "explicitFileType" => "wrapper.cfbundle", "includeInIndex" => 0, "path" => "#{TEST_TARGET}.xctest", "sourceTree" => "BUILT_PRODUCTS_DIR")
    xctest_file = add("xctest_file", "PBXFileReference", "lastKnownFileType" => "wrapper.framework", "name" => "XCTest.framework", "path" => "Platforms/iPhoneSimulator.platform/Developer/Library/Frameworks/XCTest.framework", "sourceTree" => "DEVELOPER_DIR")

    framework_refs = FRAMEWORKS.to_h do |name|
      [name, add("#{name}_file", "PBXFileReference", "lastKnownFileType" => "wrapper.xcframework", "name" => "#{name}.xcframework", "path" => FRAMEWORK_PATHS.fetch(name), "sourceTree" => "<absolute>")]
    end

    app_source_build = add("app_source_build", "PBXBuildFile", "fileRef" => app_source_file)
    test_source_build = add("test_source_build", "PBXBuildFile", "fileRef" => test_source_file)
    xctest_build = add("xctest_build", "PBXBuildFile", "fileRef" => xctest_file)
    app_refs = framework_refs.slice(*APP_FRAMEWORKS)
    test_refs = framework_refs.slice(*TEST_FRAMEWORKS)
    app_link_builds = framework_builds("app_link", app_refs)
    app_embed_builds = framework_builds("app_embed", app_refs, embed: true)
    test_link_builds = framework_builds("test_link", test_refs)
    test_embed_builds = framework_builds("test_embed", test_refs, embed: true)

    app_sources = add("app_sources", "PBXSourcesBuildPhase", "buildActionMask" => 2_147_483_647, "files" => [app_source_build], "runOnlyForDeploymentPostprocessing" => 0)
    test_sources = add("test_sources", "PBXSourcesBuildPhase", "buildActionMask" => 2_147_483_647, "files" => [test_source_build], "runOnlyForDeploymentPostprocessing" => 0)
    app_frameworks = add("app_frameworks", "PBXFrameworksBuildPhase", "buildActionMask" => 2_147_483_647, "files" => app_link_builds, "runOnlyForDeploymentPostprocessing" => 0)
    test_frameworks = add("test_frameworks", "PBXFrameworksBuildPhase", "buildActionMask" => 2_147_483_647, "files" => [xctest_build] + test_link_builds, "runOnlyForDeploymentPostprocessing" => 0)
    app_embed = embed_phase("app_embed_phase", app_embed_builds)
    test_embed = embed_phase("test_embed_phase", test_embed_builds)

    app_group = add("app_group", "PBXGroup", "children" => [app_source_file], "path" => APP_TARGET, "sourceTree" => "<group>")
    test_group = add("test_group", "PBXGroup", "children" => [test_source_file], "path" => TEST_TARGET, "sourceTree" => "<group>")
    products_group = add("products_group", "PBXGroup", "children" => [app_product, test_product], "name" => "Products", "sourceTree" => "<group>")
    frameworks_group = add("frameworks_group", "PBXGroup", "children" => framework_refs.values + [xctest_file], "name" => "Frameworks", "sourceTree" => "<group>")
    main_group = add("main_group", "PBXGroup", "children" => [app_group, test_group, frameworks_group, products_group], "sourceTree" => "<group>")

    project_config = configuration("project_debug", project_settings)
    app_config = configuration("app_debug", app_settings)
    test_config = configuration("test_debug", test_settings)
    project_config_list = config_list("project_config_list", [project_config])
    app_config_list = config_list("app_config_list", [app_config])
    test_config_list = config_list("test_config_list", [test_config])

    app_target = add("app_target", "PBXNativeTarget", "buildConfigurationList" => app_config_list, "buildPhases" => [app_sources, app_frameworks, app_embed], "buildRules" => [], "dependencies" => [], "name" => APP_TARGET, "productName" => APP_TARGET, "productReference" => app_product, "productType" => "com.apple.product-type.application")
    app_proxy = add("app_proxy", "PBXContainerItemProxy", "containerPortal" => ref("project"), "proxyType" => 1, "remoteGlobalIDString" => id("app_target"), "remoteInfo" => APP_TARGET)
    app_dependency = add("app_dependency", "PBXTargetDependency", "target" => app_target, "targetProxy" => app_proxy)
    test_target = add("test_target", "PBXNativeTarget", "buildConfigurationList" => test_config_list, "buildPhases" => [test_sources, test_frameworks, test_embed], "buildRules" => [], "dependencies" => [app_dependency], "name" => TEST_TARGET, "productName" => TEST_TARGET, "productReference" => test_product, "productType" => "com.apple.product-type.bundle.unit-test")

    add("project", "PBXProject", "attributes" => {
      "BuildIndependentTargetsInParallel" => 1,
      "LastSwiftUpdateCheck" => 1540,
      "LastUpgradeCheck" => 1540,
      "TargetAttributes" => { app_target => { "CreatedOnToolsVersion" => "15.4" }, test_target => { "CreatedOnToolsVersion" => "15.4", "TestTargetID" => app_target } }
    }, "buildConfigurationList" => project_config_list, "compatibilityVersion" => "Xcode 14.0", "developmentRegion" => "en", "hasScannedForEncodings" => 0, "knownRegions" => %w[en Base], "mainGroup" => main_group, "productRefGroup" => products_group, "projectDirPath" => "", "projectRoot" => "", "targets" => [app_target, test_target])
  end

  def framework_builds(prefix, refs, embed: false)
    refs.map do |name, file_ref|
      attrs = { "fileRef" => file_ref }
      attrs["settings"] = { "ATTRIBUTES" => %w[CodeSignOnCopy RemoveHeadersOnCopy] } if embed
      add("#{prefix}_#{name}", "PBXBuildFile", attrs)
    end
  end

  def embed_phase(label, files)
    add(label, "PBXCopyFilesBuildPhase", "buildActionMask" => 2_147_483_647, "dstPath" => "", "dstSubfolderSpec" => 10, "files" => files, "name" => "Embed Frameworks", "runOnlyForDeploymentPostprocessing" => 0)
  end

  def configuration(label, settings)
    add(label, "XCBuildConfiguration", "buildSettings" => settings, "name" => "Debug")
  end

  def config_list(label, configs)
    add(label, "XCConfigurationList", "buildConfigurations" => configs, "defaultConfigurationIsVisible" => 0, "defaultConfigurationName" => "Debug")
  end

  def project_settings
    { "ALWAYS_SEARCH_USER_PATHS" => "NO", "CLANG_ENABLE_MODULES" => "YES", "IPHONEOS_DEPLOYMENT_TARGET" => "15.0", "SDKROOT" => "iphoneos", "SUPPORTED_PLATFORMS" => "iphonesimulator iphoneos", "SWIFT_VERSION" => "5.0" }
  end

  def app_settings
    project_settings.merge("CURRENT_PROJECT_VERSION" => "1", "GENERATE_INFOPLIST_FILE" => "YES", "INFOPLIST_KEY_UILaunchScreen_Generation" => "YES", "LD_RUNPATH_SEARCH_PATHS" => ["$(inherited)", "@executable_path/Frameworks"], "MARKETING_VERSION" => "1.0", "PRODUCT_BUNDLE_IDENTIFIER" => "com.emergetools.SnapshotPreviews.BinarySmoke", "PRODUCT_NAME" => "$(TARGET_NAME)", "SWIFT_EMIT_LOC_STRINGS" => "NO", "TARGETED_DEVICE_FAMILY" => "1")
  end

  def test_settings
    project_settings.merge("BUNDLE_LOADER" => "$(TEST_HOST)", "CURRENT_PROJECT_VERSION" => "1", "ENABLE_TESTING_SEARCH_PATHS" => "YES", "GENERATE_INFOPLIST_FILE" => "YES", "LD_RUNPATH_SEARCH_PATHS" => ["$(inherited)", "@executable_path/Frameworks", "@loader_path/Frameworks"], "MARKETING_VERSION" => "1.0", "PRODUCT_BUNDLE_IDENTIFIER" => "com.emergetools.SnapshotPreviews.BinarySmokeTests", "PRODUCT_NAME" => "$(TARGET_NAME)", "SWIFT_EMIT_LOC_STRINGS" => "NO", "TARGETED_DEVICE_FAMILY" => "1", "TEST_HOST" => "$(BUILT_PRODUCTS_DIR)/#{APP_TARGET}.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/#{APP_TARGET}")
  end

  def render_project
    <<~PBX
      // !$*UTF8*$!
      {
          archiveVersion = 1;
          classes = {
          };
          objectVersion = 56;
          objects = {
      #{render_objects}
          };
          rootObject = #{id("project")};
      }
    PBX
  end

  def render_objects
    @objects.map { |object_id, attrs| "\t\t#{object_id} = #{render_value(attrs, "\t\t")};" }.join("\n")
  end

  def render_value(value, indent)
    case value
    when Ref then value.value
    when Hash
      body = value.map { |key, child| "#{indent}\t#{render_key(key)} = #{render_value(child, "#{indent}\t")};" }.join("\n")
      "{\n#{body}\n#{indent}}"
    when Array
      body = value.map { |child| "#{indent}\t#{render_value(child, "#{indent}\t")}," }.join("\n")
      "(\n#{body}\n#{indent})"
    when Integer then value.to_s
    else quote(value)
    end
  end

  def render_key(key)
    key.is_a?(Ref) ? key.value : key.to_s
  end

  def quote(value)
    string = value.to_s.gsub("\\", "\\\\").gsub('"', '\\"')
    "\"#{string}\""
  end

  def workspace
    <<~XML
      <?xml version="1.0" encoding="UTF-8"?>
      <Workspace version="1.0">
         <FileRef location="self:"></FileRef>
      </Workspace>
    XML
  end

  def app_source
    <<~SWIFT
      import PreviewGallery
      import SnapshotPreferences
      import SwiftUI

      @main
      struct BinarySmokeApp: App {
        var body: some Scene {
          WindowGroup {
            NavigationView {
              VStack(spacing: 16) {
                SmokeView()
                NavigationLink("Open Gallery") { PreviewGallery() }
              }
            }
          }
        }
      }

      struct SmokeView: View {
        var body: some View {
          Text("Binary smoke")
            .padding()
            .snapshotDiffThreshold(0.2)
            .snapshotTags(["integration": "binary"])
            .snapshotAdditionalContext(["binary_smoke": true])
            .snapshotRenderingMode(.coreAnimation)
        }
      }

      struct SmokeView_Previews: PreviewProvider {
        static var previews: some View {
          SmokeView().previewDisplayName("Binary Smoke Preview")
        }
      }
    SWIFT
  end

  def test_source
    <<~SWIFT
      import Darwin
      import SnapshottingTests
      import XCTest

      final class BinarySmokeSnapshotTest: SnapshotTest {
        override class func snapshotPreviews() -> [String]? { ["BinarySmokeApp.SmokeView_Previews"] }
        override class func snapshotPreviewModules() -> [String]? { ["BinarySmokeApp"] }
      }

      final class BinarySmokeDynamicLoadingTests: XCTestCase {
        @MainActor
        func testManuallyLinkedFrameworkDependenciesAreLoaded() {
          let loaded = Set(Bundle.allFrameworks.map { $0.bundleURL.lastPathComponent })
          for framework in ["PreviewGallery.framework", "PreviewsSupport.framework", "SnapshotPreferences.framework", "SnapshotPreviewsCore.framework", "SnapshotSharedModels.framework", "SnapshottingTests.framework"] {
            XCTAssertTrue(loaded.contains(framework), "Expected \\(framework) to be loaded; loaded: \\(loaded.sorted())")
          }
          XCTAssertNotNil(dlopen("@rpath/SnapshottingTests.framework/SnapshottingTests", RTLD_NOW))
          XCTAssertNotNil(dlopen("@rpath/PreviewGallery.framework/PreviewGallery", RTLD_NOW))
          XCTAssertNotNil(dlopen("@rpath/SnapshotPreferences.framework/SnapshotPreferences", RTLD_NOW))
        }
      }
    SWIFT
  end

  def scheme
    app_ref = buildable_ref(id("app_target"), APP_TARGET, "#{APP_TARGET}.app")
    test_ref = buildable_ref(id("test_target"), TEST_TARGET, "#{TEST_TARGET}.xctest")
    <<~XML
      <?xml version="1.0" encoding="UTF-8"?>
      <Scheme LastUpgradeVersion="1540" version="1.7">
        <BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">#{app_ref}</BuildActionEntry><BuildActionEntry buildForTesting="YES" buildForRunning="NO" buildForProfiling="NO" buildForArchiving="NO" buildForAnalyzing="YES">#{test_ref}</BuildActionEntry></BuildActionEntries></BuildAction>
        <TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.DebuggerFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="YES"><Testables><TestableReference skipped="NO" parallelizable="NO">#{test_ref}</TestableReference></Testables><MacroExpansion>#{app_ref}</MacroExpansion></TestAction>
        <LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.DebuggerFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" debugServiceExtension="internal" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0">#{app_ref}</BuildableProductRunnable></LaunchAction>
        <ProfileAction buildConfiguration="Debug" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"><BuildableProductRunnable runnableDebuggingMode="0">#{app_ref}</BuildableProductRunnable></ProfileAction>
        <AnalyzeAction buildConfiguration="Debug"/><ArchiveAction buildConfiguration="Debug" revealArchiveInOrganizer="YES"/>
      </Scheme>
    XML
  end

  def buildable_ref(target_id, target_name, buildable_name)
    "<BuildableReference BuildableIdentifier=\"primary\" BlueprintIdentifier=\"#{target_id}\" BuildableName=\"#{buildable_name}\" BlueprintName=\"#{target_name}\" ReferencedContainer=\"container:#{PROJECT_NAME}.xcodeproj\"/>"
  end
end

class SmokeRunner
  def run
    ensure_artifacts!
    project = SmokeProject.new
    project.write
    run_xcodebuild(project.project_path)
    validate_export!
    puts "Binary integration iOS smoke passed."
  end

  private

  def ensure_artifacts!
    missing = FRAMEWORK_PATHS.reject { |_name, path| File.directory?(path) }
    abort "Missing XCFramework artifacts: #{missing.map { |name, path| "#{name} at #{path}" }.join(", ")}. Run bash build.sh first." unless missing.empty?
  end

  def run_xcodebuild(project_path)
    FileUtils.rm_rf([EXPORT_DIR, RESULT_BUNDLE_PATH])
    FileUtils.mkdir_p(EXPORT_DIR)
    command = ["xcodebuild", "test", "-project", project_path, "-scheme", PROJECT_NAME, "-destination", "id=#{ios_simulator_udid}", "-derivedDataPath", DERIVED_DATA_DIR, "-resultBundlePath", RESULT_BUNDLE_PATH, "CODE_SIGNING_ALLOWED=NO"]
    env = { "TEST_RUNNER_SNAPSHOTS_EXPORT_DIR" => EXPORT_DIR, "TEST_RUNNER_EMERGE_DISABLE_FIX_TIME" => "1" }
    puts [env.map { |key, value| "#{key}=#{value.shellescape}" }, command.map(&:shellescape)].flatten.join(" ")
    abort "Binary integration iOS smoke xcodebuild failed." unless system(env, *command)
  end

  def ios_simulator_udid
    stdout, status = Open3.capture2("xcrun", "simctl", "list", "devices", "available", "--json")
    abort "Failed to list iOS simulators with xcrun simctl." unless status.success?

    devices = JSON.parse(stdout).fetch("devices").select { |runtime, _| runtime.include?("iOS") }.values.flatten
    candidates = devices.select { |device| device["isAvailable"] && device.fetch("name", "").start_with?("iPhone") }
    selected = candidates.find { |device| device["state"] == "Booted" } || candidates.find { |device| device["name"].include?("15") } || candidates.first
    abort "No available iPhone simulator found for binary integration smoke." unless selected

    selected.fetch("udid")
  end

  def validate_export!
    pngs = Dir.glob(File.join(EXPORT_DIR, "**", "*.png"))
    jsons = Dir.glob(File.join(EXPORT_DIR, "**", "*.json"))
    abort "Expected exported snapshot PNGs in #{EXPORT_DIR}, found none." if pngs.empty?
    abort "Expected exported snapshot JSON sidecars in #{EXPORT_DIR}, found none." if jsons.empty?

    sidecars = jsons.map { |path| [path, JSON.parse(File.read(path))] }
    path, sidecar = sidecars.find { |_path, data| data["display_name"] == "Binary Smoke Preview" || data.dig("context", "preview", "display_name") == "Binary Smoke Preview" }
    abort "Expected a Binary Smoke Preview sidecar in #{jsons.join(", ")}." unless sidecar
    abort "Expected exported sidecar tags to include integration=binary in #{path}." unless sidecar.fetch("tags", {})["integration"] == "binary"
    abort "Expected exported sidecar context to include binary_smoke=true in #{path}." unless sidecar.fetch("context", {})["binary_smoke"] == true
  end
end

SmokeRunner.new.run
