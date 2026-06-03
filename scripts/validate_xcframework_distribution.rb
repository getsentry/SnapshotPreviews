#!/usr/bin/env ruby
# frozen_string_literal: true

require "find"
require "set"
require_relative "xcframework_distribution"

module XCFrameworkDistribution
  class Validator
    def initialize
      @errors = []
    end

    def run
      validate_previews_support_slices
      FRAMEWORKS.each { |framework| validate_framework(framework) }
      finish
    end

    private

    def validate_previews_support_slices
      validate_required_slices(XCFrameworkDistribution.distributed_xcframework_path("PreviewsSupport"), "PreviewsSupport")
    end

    def validate_framework(framework)
      xcframework_path = XCFrameworkDistribution.distributed_xcframework_path(framework.name)
      unless File.directory?(xcframework_path)
        error "Missing #{xcframework_path}"
        return
      end

      validate_required_slices(xcframework_path, framework.name)
      XCFrameworkDistribution.available_libraries(xcframework_path).each do |library|
        validate_library(framework, xcframework_path, library)
      end
    end

    def validate_required_slices(xcframework_path, name)
      unless File.directory?(xcframework_path)
        error "Missing #{xcframework_path}"
        return
      end

      identifiers = XCFrameworkDistribution.available_libraries(xcframework_path).map { |entry| entry.fetch("LibraryIdentifier") }
      missing = XCFrameworkDistribution.required_platform_missing_identifiers(identifiers)
      return if missing.empty?

      formatted = missing.join(", ")
      error "#{name}.xcframework missing required slices: #{formatted}"
    end

    def validate_library(framework, xcframework_path, library)
      identifier = library.fetch("LibraryIdentifier")
      library_path = library.fetch("LibraryPath")
      framework_dir = File.join(xcframework_path, identifier, library_path)
      binary_path = binary_path_for(framework, xcframework_path, identifier, library_path, library["BinaryPath"])

      unless File.file?(binary_path)
        error "#{framework.name} #{identifier} missing binary at #{binary_path}"
        return
      end

      validate_nested_frameworks(framework, identifier, framework_dir)
      validate_macos_module_placement(framework, identifier, library, framework_dir)
      validate_swift_interfaces(framework, identifier, framework_dir)
      validate_dynamic_loads(framework, identifier, binary_path)
    end

    def binary_path_for(framework, xcframework_path, identifier, library_path, binary_path)
      return File.join(xcframework_path, identifier, binary_path) if binary_path && !binary_path.empty?

      framework_dir = File.join(xcframework_path, identifier, library_path)
      executable_path = if File.directory?(File.join(framework_dir, "Versions/A"))
                          File.join(framework_dir, "Versions/A", framework.name)
                        else
                          File.join(framework_dir, framework.name)
                        end
      executable_path
    end

    def validate_nested_frameworks(framework, identifier, framework_dir)
      return unless File.directory?(framework_dir)

      root = File.expand_path(framework_dir)
      Find.find(framework_dir) do |path|
        next unless path.end_with?(".framework")

        expanded = File.expand_path(path)
        next if expanded == root

        error "#{framework.name} #{identifier} contains nested framework #{path}"
        Find.prune
      end
    end

    def validate_macos_module_placement(framework, identifier, library, framework_dir)
      return unless framework.requires_swift_module
      return unless library.fetch("SupportedPlatform") == "macos" && !library.key?("SupportedPlatformVariant")

      versioned_modules = File.join(framework_dir, "Versions/A/Modules/#{framework.name}.swiftmodule")
      root_modules = File.join(framework_dir, "Modules")
      error "#{framework.name} #{identifier} missing macOS versioned Swift module at #{versioned_modules}" unless File.directory?(versioned_modules)
      error "#{framework.name} #{identifier} Modules should symlink to Versions/Current/Modules" unless File.symlink?(root_modules)
    end

    def validate_swift_interfaces(framework, identifier, framework_dir)
      return unless framework.requires_swift_module

      module_dir = swift_module_dir(framework, framework_dir)
      unless module_dir && File.directory?(module_dir)
        error "#{framework.name} #{identifier} missing Swift module directory"
        return
      end

      interfaces = Dir.glob(File.join(module_dir, "*.swiftinterface"))
      if interfaces.empty?
        error "#{framework.name} #{identifier} missing .swiftinterface files in #{module_dir}"
        return
      end

      interfaces.each do |interface_path|
        imports = swift_interface_imports(interface_path)
        unexpected_project = (imports & PROJECT_FRAMEWORK_NAMES.to_set) - framework.allowed_interface_imports.to_set - [framework.name].to_set
        unless unexpected_project.empty?
          error "#{framework.name} #{identifier} interface #{interface_path} imports unexpected project modules: #{unexpected_project.to_a.sort.join(", ")}"
        end

        unexpected_modules = imports & disallowed_interface_modules
        unless unexpected_modules.empty?
          error "#{framework.name} #{identifier} interface #{interface_path} imports non-public implementation modules: #{unexpected_modules.to_a.sort.join(", ")}"
        end

        forbidden_references = forbidden_interface_references(interface_path)
        next if forbidden_references.empty?

        error "#{framework.name} #{identifier} interface #{interface_path} contains forbidden references: #{forbidden_references.to_a.sort.join(", ")}"
      end
    end

    def swift_module_dir(framework, framework_dir)
      candidates = [
        File.join(framework_dir, "Versions/A/Modules/#{framework.name}.swiftmodule"),
        File.join(framework_dir, "Modules/#{framework.name}.swiftmodule")
      ]
      candidates.find { |candidate| File.directory?(candidate) }
    end

    def swift_interface_imports(interface_path)
      imports = Set.new
      File.foreach(interface_path) do |line|
        module_name = swift_interface_import_module(line)
        imports << module_name unless module_name.nil?
      end
      imports
    end

    def swift_interface_import_module(line)
      tokens = line.strip.split
      tokens.shift while tokens.first&.start_with?("@")
      tokens.shift while %w[public internal package private fileprivate].include?(tokens.first)
      return nil unless tokens.shift == "import"

      tokens.shift if %w[class struct enum protocol func var let typealias].include?(tokens.first)
      tokens.first&.split(".")&.first
    end

    def disallowed_interface_modules
      private_modules = FRAMEWORKS.flat_map(&:private_source_targets)
      (private_modules + EXTERNAL_PACKAGES.keys).to_set
    end

    def forbidden_interface_references(interface_path)
      references = Set.new
      content = File.read(interface_path)
      references << "NSInvocation" if content.include?("NSInvocation")
      references
    end

    def validate_dynamic_loads(framework, identifier, binary_path)
      binary_architectures(binary_path).each do |architecture|
        loads = dynamic_loads(binary_path, architecture, framework.name, identifier)
        next if loads.nil?

        validation_identifier = architecture.nil? ? identifier : "#{identifier} #{architecture}"
        validate_project_dynamic_loads(framework, validation_identifier, loads)
        validate_unexpected_dynamic_loads(framework, validation_identifier, loads)
      end
    end

    def binary_architectures(binary_path)
      stdout, status = command_output(["lipo", "-archs", binary_path])
      return [nil] unless status.success?

      architectures = stdout.split
      architectures.empty? ? [nil] : architectures
    end

    def dynamic_loads(binary_path, architecture, framework_name, identifier)
      command = architecture.nil? ? ["otool", "-L", binary_path] : ["otool", "-arch", architecture, "-L", binary_path]
      stdout, status = command_output(command)
      unless status.success?
        error "#{command.join(" ")} failed for #{framework_name} #{identifier}"
        return nil
      end

      stdout.lines.each_with_object([]) do |line, loads|
        candidate = line.strip.split(/\s+/).first
        next if candidate.nil? || candidate.empty? || candidate.end_with?(":")

        loads << candidate
      end
    end

    def validate_project_dynamic_loads(framework, identifier, loads)
      actual_project_loads = loads.each_with_object(Set.new) do |load, project_loads|
        canonical = canonical_project_load(load)
        project_loads << canonical unless canonical.nil?
      end
      expected_project_loads = framework.expected_project_loads.to_set

      missing = expected_project_loads - actual_project_loads
      unexpected = actual_project_loads - expected_project_loads - [XCFrameworkDistribution.project_load(framework.name)].to_set
      error "#{framework.name} #{identifier} missing project dynamic loads: #{missing.to_a.sort.join(", ")}" unless missing.empty?
      error "#{framework.name} #{identifier} has unexpected project dynamic loads: #{unexpected.to_a.sort.join(", ")}" unless unexpected.empty?
    end

    def canonical_project_load(load)
      name = framework_name_from_load(load)
      return nil unless PROJECT_FRAMEWORK_NAMES.include?(name)

      XCFrameworkDistribution.project_load(name)
    end

    def framework_name_from_load(load)
      match = load.match(%r{\A@rpath/([^/]+)\.framework/(?:Versions/[^/]+/)?\1\z})
      match && match[1]
    end

    def validate_unexpected_dynamic_loads(framework, identifier, loads)
      loads.each do |load|
        name = framework_name_from_load(load)
        if UNEXPECTED_THIRD_PARTY_FRAMEWORKS.include?(name)
          error "#{framework.name} #{identifier} has unexpected third-party dynamic load #{load}"
          next
        end

        next unless load.start_with?("@rpath/")
        next if load.start_with?("@rpath/libswift")
        next if ALLOWED_APPLE_RPATH_DYLIBS.include?(File.basename(load))

        if name.nil?
          error "#{framework.name} #{identifier} has unexpected non-system dynamic load #{load}"
          next
        end

        next if PROJECT_FRAMEWORK_NAMES.include?(name)
        next if ALLOWED_APPLE_RPATH_FRAMEWORKS.include?(name)

        error "#{framework.name} #{identifier} has unexpected non-system dynamic load #{load}"
      end
    end

    def command_output(command)
      output = IO.popen(command, &:read)
      [output, $?]
    end

    def error(message)
      @errors << message
    end

    def finish
      if @errors.empty?
        puts "XCFramework distribution validation passed."
        $stdout.flush
        exit!(0)
      else
        warn "XCFramework distribution validation failed:"
        @errors.each { |message| warn "- #{message}" }
        $stderr.flush
        exit!(1)
      end
    end
  end
end

XCFrameworkDistribution::Validator.new.run
