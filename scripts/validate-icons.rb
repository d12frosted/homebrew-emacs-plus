#!/usr/bin/env ruby
# frozen_string_literal: true

require 'digest'
require 'json'
require 'pathname'

# Validation script for community icon files
class IconValidator
  REPO_ROOT = Pathname.new(__dir__).parent
  COMMUNITY_ICONS_DIR = REPO_ROOT / 'community' / 'icons'
  REGISTRY_FILE = REPO_ROOT / 'community' / 'registry.json'

  def initialize
    @errors = []
    @warnings = []
    @registry = JSON.parse(File.read(REGISTRY_FILE))
  end

  def validate!
    puts "Validating community icons..."
    puts

    validate_registry_icons_exist
    validate_icon_metadata
    validate_icns_files

    print_results
    exit(1) unless @errors.empty?
  end

  private

  def validate_registry_icons_exist
    puts "Checking that all icons in registry exist on disk..."
    @registry['icons'].each do |name, info|
      icon_dir = REPO_ROOT / 'community' / info['directory']
      icon_file = icon_dir / 'icon.icns'

      unless icon_dir.exist?
        @errors << "Icon '#{name}' directory does not exist: #{icon_dir}"
        next
      end

      unless icon_file.exist?
        @errors << "Icon '#{name}' is missing icon.icns file: #{icon_file}"
      end
    end
    puts "  #{@registry['icons'].size} icons checked"
    puts
  end

  def validate_icon_metadata
    puts "Checking icon metadata files..."
    @registry['icons'].each do |name, info|
      icon_dir = REPO_ROOT / 'community' / info['directory']
      metadata_file = icon_dir / 'metadata.json'

      unless metadata_file.exist?
        @warnings << "Icon '#{name}' is missing metadata.json"
        next
      end

      begin
        metadata = JSON.parse(File.read(metadata_file))
        unless metadata['maintainer']
          @warnings << "Icon '#{name}' metadata is missing 'maintainer' field"
        end
      rescue JSON::ParserError => e
        @errors << "Icon '#{name}' has invalid metadata.json: #{e.message}"
      end
    end
    puts "  Metadata validated"
    puts
  end

  def validate_icns_files
    puts "Validating .icns files are valid..."
    @registry['icons'].each do |name, info|
      icon_dir = REPO_ROOT / 'community' / info['directory']
      icon_file = icon_dir / 'icon.icns'

      next unless icon_file.exist?

      # Check file has valid icns magic bytes
      magic = File.binread(icon_file, 4)
      unless magic == 'icns'
        @errors << "Icon '#{name}' has invalid icns file (bad magic bytes)"
      end
    end
    puts "  All .icns files validated"
    puts
  end

  def print_results
    puts '=' * 80
    puts

    if @warnings.any?
      puts "Warnings:"
      @warnings.each do |warning|
        puts "  - #{warning}"
      end
      puts
    end

    if @errors.any?
      puts "Errors:"
      @errors.each do |error|
        puts "  x #{error}"
      end
      puts
      puts "Validation FAILED with #{@errors.size} error(s) and #{@warnings.size} warning(s)"
    else
      puts "All validations passed!"
      puts "  #{@registry['icons'].size} icons validated successfully"
    end

    puts '=' * 80
  end
end

# Run validation if script is executed directly
IconValidator.new.validate! if __FILE__ == $PROGRAM_NAME
