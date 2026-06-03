#!/usr/bin/env ruby
# frozen_string_literal: true

require "fileutils"
require "find"
require "open3"
require_relative "xcframework_distribution"

module XCFrameworkDistribution
  class Builder
    def initialize
      configured_build_dir = ENV.fetch("PROJECT_BUILD_DIR", "build")
      @project_build_dir = File.expand_path(configured_build_dir, ROOT)
      @distribution_build_dir = File.join(@project_build_dir, "xcframework-distribution")
      @temp_packages_dir = File.join(@distribution_build_dir, "temp-packages")
      @xcodebuild_build_dir = File.join(@project_build_dir, "xcodebuild")
    end

    def run
      validate_previews_support!
      FileUtils.mkdir_p([@temp_packages_dir, DISTRIBUTION_DIR])
      copy_previews_support_to_distribution
      FRAMEWORKS.each { |framework| build_framework(framework) }
      puts "XCFramework builds completed successfully in #{DISTRIBUTION_DIR}."
    end

    private

    def validate_previews_support!
      unless File.directory?(PREVIEWS_SUPPORT_XCFRAMEWORK)
        abort "Missing #{PREVIEWS_SUPPORT_XCFRAMEWORK}. Run PreviewsSupport/build.sh or restore the checked-in artifact."
      end

      identifiers = XCFrameworkDistribution.available_libraries(PREVIEWS_SUPPORT_XCFRAMEWORK).map { |entry| entry.fetch("LibraryIdentifier") }
      missing = XCFrameworkDistribution.required_platform_missing_identifiers(identifiers)
      return if missing.empty?

      formatted = missing.join(", ")
      abort "PreviewsSupport.xcframework is missing required distribution slices: #{formatted}. Run PreviewsSupport/build.sh."
    end

    def copy_previews_support_to_distribution
      destination = XCFrameworkDistribution.distributed_xcframework_path("PreviewsSupport")
      FileUtils.rm_rf(destination)
      FileUtils.cp_r(PREVIEWS_SUPPORT_XCFRAMEWORK, destination)
    end

    def build_framework(framework)
      package_dir = File.join(@temp_packages_dir, framework.name)
      archives_dir = File.join(package_dir, "archives")
      derived_data_path = File.join(@xcodebuild_build_dir, "DerivedData", framework.name)

      FileUtils.rm_rf(package_dir)
      FileUtils.mkdir_p([archives_dir, File.join(package_dir, "Sources")])
      copy_source_targets(framework, package_dir)
      copy_binary_dependencies(framework, package_dir)
      write_manifest(framework, package_dir)
      validate_build_scheme!(framework, package_dir)

      PLATFORMS.each do |platform|
        archive_path = File.join(archives_dir, "#{framework.name}-#{platform.sdk}.xcarchive")
        FileUtils.rm_rf(archive_path)
        archive_framework(framework, platform, package_dir, archive_path, derived_data_path)
        copy_swift_module(framework, platform.sdk, archive_path, derived_data_path)
      end

      create_xcframework(framework, archives_dir)
      FileUtils.rm_rf(archives_dir)
    end

    def copy_source_targets(framework, package_dir)
      framework.all_source_targets.each do |target|
        source = File.join(ROOT, "Sources", target)
        abort "Missing source target #{source}" unless File.directory?(source)

        FileUtils.cp_r(source, File.join(package_dir, "Sources"))
        include_dir = File.join(package_dir, "Sources", target, "include")
        FileUtils.mkdir_p(include_dir) if framework.public_header_targets.include?(target)
      end
    end

    def copy_binary_dependencies(framework, package_dir)
      return if framework.all_binary_dependencies.empty?

      binary_dir = File.join(package_dir, "BinaryDependencies")
      FileUtils.mkdir_p(binary_dir)

      framework.all_binary_dependencies.each do |dependency|
        source = XCFrameworkDistribution.distributed_xcframework_path(dependency)
        abort "Missing binary dependency #{dependency} for #{framework.name} at #{source}" unless File.directory?(source)

        destination = File.join(binary_dir, "#{dependency}.xcframework")
        FileUtils.rm_rf(destination)
        FileUtils.cp_r(source, destination)
      end
    end

    def write_manifest(framework, package_dir)
      File.write(File.join(package_dir, "Package.swift"), manifest(framework))
    end

    def manifest(framework)
      dependencies = framework.external_packages.map { |name| EXTERNAL_PACKAGES.fetch(name) }
      binary_targets = framework.all_binary_dependencies.map do |name|
        "        .binaryTarget(name: \"#{name}\", path: \"BinaryDependencies/#{name}.xcframework\")"
      end
      source_targets = framework.all_source_targets.map { |target| target_manifest(framework, target) }
      targets = (binary_targets + source_targets).join(",\n")
      dependency_block = dependencies.empty? ? "" : dependencies.map { |line| "      #{line}" }.join(",\n")

      <<~SWIFT
        // swift-tools-version: 5.7
        import PackageDescription

        let package = Package(
            name: "#{framework.name}Distribution",
            platforms: [.iOS(.v15), .macOS(.v12), .watchOS(.v9)],
            products: [
                .library(name: "#{framework.name}", type: .dynamic, targets: ["#{framework.name}"])
            ],
            dependencies: [
        #{dependency_block}
            ],
            targets: [
        #{targets}
            ],
            cxxLanguageStandard: .cxx11
        )
      SWIFT
    end

    def target_manifest(framework, target)
      dependency_expressions = framework.target_dependencies.fetch(target, []).map { |dependency| swift_dependency_expression(dependency) }
      attributes = ["name: \"#{target}\""]
      attributes << "dependencies: [#{dependency_expressions.join(", ")}]" unless dependency_expressions.empty?
      attributes << "publicHeadersPath: \"include\"" if framework.public_header_targets.include?(target)

      linker_settings = linker_settings_for(framework, target)
      attributes << "linkerSettings: #{linker_settings}" unless linker_settings.nil?

      "        .target(#{attributes.join(", ")})"
    end

    def swift_dependency_expression(dependency)
      dependency.start_with?(".") ? dependency : "\"#{dependency}\""
    end

    def linker_settings_for(framework, target)
      return nil unless target == framework.name
      return nil if framework.linker_retained_dependencies.empty?

      flags = framework.linker_retained_dependencies.flat_map { |name| ["-Xlinker", "-needed_framework", "-Xlinker", name] }
      swift_flags = flags.map { |flag| "\"#{flag}\"" }.join(", ")
      "[.unsafeFlags([#{swift_flags}])]"
    end

    def validate_build_scheme!(framework, package_dir)
      expected_scheme = build_scheme(framework)
      command = ["xcodebuild", "-list", "-json"]
      stdout, stderr, status = Dir.chdir(package_dir) { Open3.capture3(*command) }
      unless status.success?
        abort "Failed to inspect generated package schemes for #{framework.name}: #{stderr}"
      end

      available_schemes = package_schemes(stdout)
      return if available_schemes.include?(expected_scheme)

      formatted_schemes = available_schemes.empty? ? "none" : available_schemes.sort.join(", ")
      abort "Generated package for #{framework.name} did not expose expected scheme #{expected_scheme.inspect}. Available schemes: #{formatted_schemes}. This build expects Xcode to expose the package scheme <Name>Distribution; do not switch to a product scheme without rerunning the package-scheme spike."
    end

    def package_schemes(xcodebuild_list_json)
      parsed = JSON.parse(xcodebuild_list_json)
      Array(parsed.dig("project", "schemes")) + Array(parsed.dig("workspace", "schemes"))
    rescue JSON::ParserError => error
      abort "Failed to parse xcodebuild -list -json output: #{error.message}"
    end

    def archive_framework(framework, platform, package_dir, archive_path, derived_data_path)
      command = [
        "xcodebuild", "archive",
        "-scheme", build_scheme(framework),
        "-archivePath", archive_path,
        "-derivedDataPath", derived_data_path,
        "-sdk", platform.sdk,
        "-destination", platform.destination,
        "BUILD_LIBRARY_FOR_DISTRIBUTION=YES",
        "INSTALL_PATH=Library/Frameworks",
        "SKIP_INSTALL=NO",
        "OTHER_SWIFT_FLAGS=-no-verify-emitted-module-interface"
      ]
      run_command(command, chdir: package_dir)
    end

    def copy_swift_module(framework, sdk, archive_path, derived_data_path)
      build_products_configuration = sdk == "macosx" ? "Release" : "Release-#{sdk}"
      source_module_path = File.join(
        derived_data_path,
        "Build/Intermediates.noindex/ArchiveIntermediates/#{build_scheme(framework)}/BuildProductsPath",
        build_products_configuration,
        "#{framework.name}.swiftmodule"
      )

      unless File.directory?(source_module_path)
        abort "Missing Swift module artifacts for #{framework.name} (#{sdk}) at #{source_module_path}" if framework.requires_swift_module
        return
      end

      framework_path = File.join(archive_path, "Products/Library/Frameworks/#{framework.name}.framework")
      modules_path = File.join(framework_path, "Modules")
      versions_modules_path = File.join(framework_path, "Versions/A/Modules")
      if sdk == "macosx" && File.directory?(File.join(framework_path, "Versions/A"))
        modules_path = versions_modules_path
        FileUtils.rm_rf(File.join(framework_path, "Modules"))
        FileUtils.ln_s("Versions/Current/Modules", File.join(framework_path, "Modules"))
      end

      FileUtils.mkdir_p(modules_path)
      destination = File.join(modules_path, "#{framework.name}.swiftmodule")
      FileUtils.rm_rf(destination)
      FileUtils.cp_r(source_module_path, destination)
      sanitize_swift_interfaces(modules_path, framework.name)
    end

    def sanitize_swift_interfaces(modules_path, framework_name)
      Find.find(modules_path) do |path|
        next unless File.file?(path)

        if path.end_with?(".private.swiftinterface")
          FileUtils.rm_f(path)
        elsif path.end_with?(".swiftinterface")
          content = File.read(path)
          File.write(path, sanitized_swift_interface(content, framework_name))
        end
      end
    end

    def sanitized_swift_interface(content, framework_name)
      content.lines.each_with_object([]) do |line, sanitized_lines|
        next if line.include?("NSInvocation")

        sanitized_lines << sanitize_swift_interface_line(line, framework_name)
      end.join
    end

    def sanitize_swift_interface_line(line, framework_name)
      escaped_framework_name = Regexp.escape(framework_name)
      line.gsub(/\bXCTest\.(?=[A-Z_])/, "")
          .gsub(/\b#{escaped_framework_name}\.(?=[A-Z_])/, "")
    end

    def create_xcframework(framework, archives_dir)
      output_path = XCFrameworkDistribution.distributed_xcframework_path(framework.name)
      FileUtils.rm_rf(output_path)
      command = ["xcodebuild", "-create-xcframework"]
      PLATFORMS.each do |platform|
        command << "-framework"
        command << File.join(archives_dir, "#{framework.name}-#{platform.sdk}.xcarchive", "Products/Library/Frameworks/#{framework.name}.framework")
      end
      command << "-output" << output_path
      run_command(command)
    end

    def build_scheme(framework)
      "#{framework.name}Distribution"
    end

    def run_command(command, chdir: nil)
      puts command.join(" ")
      success = chdir.nil? ? system(*command) : Dir.chdir(chdir) { system(*command) }
      abort "Command failed: #{command.join(" ")}" unless success
    end
  end
end

XCFrameworkDistribution::Builder.new.run
