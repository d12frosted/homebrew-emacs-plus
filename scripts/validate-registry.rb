#!/usr/bin/env ruby
# frozen_string_literal: true

# Script to validate the community registry and all referenced files
# Usage: ruby scripts/validate-registry.rb
# Exit codes: 0 = valid, 1 = errors found

require 'json'

REPO_ROOT = File.expand_path('..', __dir__)
COMMUNITY_DIR = File.join(REPO_ROOT, 'community')
REGISTRY_FILE = File.join(COMMUNITY_DIR, 'registry.json')

SUPPORTED_VERSIONS = %w[29 30 31].freeze

class RegistryValidator
  def initialize
    @errors = []
    @warnings = []
  end

  def error(message)
    @errors << message
    puts "  ERROR: #{message}"
  end

  def warning(message)
    @warnings << message
    puts "  WARNING: #{message}"
  end

  def validate
    puts "Validating community registry..."
    puts

    unless File.exist?(REGISTRY_FILE)
      error("Registry file not found: #{REGISTRY_FILE}")
      return false
    end

    begin
      @registry = JSON.parse(File.read(REGISTRY_FILE))
    rescue JSON::ParserError => e
      error("Invalid JSON in registry: #{e.message}")
      return false
    end

    validate_schema
    validate_patches
    validate_icons

    puts
    puts "=" * 60
    if @errors.empty?
      puts "Validation PASSED"
      puts "  #{@warnings.length} warning(s)" unless @warnings.empty?
      true
    else
      puts "Validation FAILED"
      puts "  #{@errors.length} error(s)"
      puts "  #{@warnings.length} warning(s)" unless @warnings.empty?
      false
    end
  end

  private

  def validate_schema
    puts "Checking schema..."

    unless @registry['schema_version']
      error("Missing schema_version")
    end

    unless @registry['patches'].is_a?(Hash)
      error("'patches' must be an object")
    end

    unless @registry['icons'].is_a?(Hash)
      error("'icons' must be an object")
    end
  end

  def validate_patches
    puts "Checking patches..."
    patches = @registry['patches'] || {}

    if patches.empty?
      puts "  (no patches registered)"
      return
    end

    patches.each do |name, info|
      puts "  Checking patch: #{name}"

      unless info['directory']
        error("Patch '#{name}' missing 'directory' field")
        next
      end

      patch_dir = File.join(COMMUNITY_DIR, info['directory'])
      unless Dir.exist?(patch_dir)
        error("Patch directory not found: #{patch_dir}")
        next
      end

      validate_patch_contents(name, patch_dir)
    end
  end

  def validate_patch_contents(name, patch_dir)
    # Check metadata.json
    metadata_file = File.join(patch_dir, 'metadata.json')
    unless File.exist?(metadata_file)
      error("Patch '#{name}' missing metadata.json")
      return
    end

    begin
      metadata = JSON.parse(File.read(metadata_file))
    rescue JSON::ParserError => e
      error("Patch '#{name}' has invalid metadata.json: #{e.message}")
      return
    end

    # Validate required metadata fields
    %w[name description maintainer].each do |field|
      unless metadata[field]
        error("Patch '#{name}' metadata missing required field: #{field}")
      end
    end

    # Check compatibility
    unless metadata.dig('compatibility', 'emacs_versions')
      error("Patch '#{name}' metadata missing compatibility.emacs_versions")
      return
    end

    versions = metadata.dig('compatibility', 'emacs_versions')
    unless versions.is_a?(Array) && !versions.empty?
      error("Patch '#{name}' must support at least one Emacs version")
      return
    end

    invalid_versions = versions - SUPPORTED_VERSIONS
    unless invalid_versions.empty?
      warning("Patch '#{name}' lists unsupported versions: #{invalid_versions.join(', ')}")
    end

    # Check patch files exist for each supported version
    versions.each do |ver|
      next unless SUPPORTED_VERSIONS.include?(ver)

      patch_file = File.join(patch_dir, "emacs-#{ver}.patch")
      unless File.exist?(patch_file)
        error("Patch '#{name}' missing patch file for Emacs #{ver}: #{patch_file}")
      end
    end
  end

  def validate_icons
    puts "Checking icons..."
    icons = @registry['icons'] || {}

    if icons.empty?
      puts "  (no icons registered)"
      return
    end

    icons.each do |name, info|
      puts "  Checking icon: #{name}"

      unless info['directory']
        error("Icon '#{name}' missing 'directory' field")
        next
      end

      icon_dir = File.join(COMMUNITY_DIR, info['directory'])
      unless Dir.exist?(icon_dir)
        error("Icon directory not found: #{icon_dir}")
        next
      end

      validate_icon_contents(name, icon_dir)
    end
  end

  def validate_icon_contents(name, icon_dir)
    # Check icon.icns exists
    icon_file = File.join(icon_dir, 'icon.icns')
    unless File.exist?(icon_file)
      error("Icon '#{name}' missing icon.icns")
      return
    end

    # Validate icns magic number
    magic = File.binread(icon_file, 4)
    unless magic == 'icns'
      error("Icon '#{name}' has invalid .icns file (bad magic number)")
    end

    # Check metadata.json exists
    metadata_file = File.join(icon_dir, 'metadata.json')
    unless File.exist?(metadata_file)
      warning("Icon '#{name}' missing metadata.json")
      return
    end

    begin
      metadata = JSON.parse(File.read(metadata_file))
    rescue JSON::ParserError => e
      error("Icon '#{name}' has invalid metadata.json: #{e.message}")
      return
    end

    # Validate required metadata fields
    %w[name].each do |field|
      unless metadata[field]
        warning("Icon '#{name}' metadata missing field: #{field}")
      end
    end
  end
end

if __FILE__ == $PROGRAM_NAME
  validator = RegistryValidator.new
  exit(validator.validate ? 0 : 1)
end
