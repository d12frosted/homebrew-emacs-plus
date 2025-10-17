#!/usr/bin/env ruby
# frozen_string_literal: true

require 'digest'
require 'pathname'
require_relative '../Library/Icons'

# Validation script for icon files and their SHA256 checksums
class IconValidator
  ICONS_DIR = Pathname.new(__dir__).parent / 'icons'
  EXCLUDED_FILES = ['.DS_Store'].freeze

  def initialize
    @errors = []
    @warnings = []
  end

  def validate!
    puts "Validating icons in #{ICONS_DIR}..."
    puts

    validate_icons_config_files_exist
    validate_all_icon_files_in_config
    validate_checksums

    print_results
    exit(1) unless @errors.empty?
  end

  private

  def validate_icons_config_files_exist
    puts "Checking that all icons in ICONS_CONFIG exist on disk..."
    ICONS_CONFIG.each_key do |icon_name|
      icon_path = ICONS_DIR / "#{icon_name}.icns"
      unless icon_path.exist?
        @errors << "Icon '#{icon_name}' is defined in ICONS_CONFIG but file '#{icon_path}' does not exist"
      end
    end
    puts "  ✓ All icons in ICONS_CONFIG exist on disk" if @errors.empty?
    puts
  end

  def validate_all_icon_files_in_config
    puts "Checking that all icon files are mentioned in ICONS_CONFIG..."
    icon_files = Dir.glob(ICONS_DIR / '*.icns').map do |path|
      File.basename(path, '.icns')
    end

    icon_files.each do |icon_name|
      next if EXCLUDED_FILES.include?("#{icon_name}.icns")

      unless ICONS_CONFIG.key?(icon_name)
        @warnings << "Icon file '#{icon_name}.icns' exists but is not defined in ICONS_CONFIG"
      end
    end

    if @warnings.empty?
      puts "  ✓ All icon files are mentioned in ICONS_CONFIG"
    else
      puts "  ⚠ Some icon files are not in ICONS_CONFIG (see warnings below)"
    end
    puts
  end

  def validate_checksums
    puts "Validating SHA256 checksums..."
    ICONS_CONFIG.each do |icon_name, expected_sha|
      icon_path = ICONS_DIR / "#{icon_name}.icns"
      next unless icon_path.exist?

      actual_sha = Digest::SHA256.file(icon_path).hexdigest
      if actual_sha != expected_sha
        @errors << "SHA256 mismatch for '#{icon_name}':\n" \
                   "  Expected: #{expected_sha}\n" \
                   "  Actual:   #{actual_sha}\n" \
                   "  File:     #{icon_path}"
      end
    end
    puts "  ✓ All SHA256 checksums are correct" if @errors.select { |e| e.include?('SHA256') }.empty?
    puts
  end

  def print_results
    puts '=' * 80
    puts

    if @warnings.any?
      puts "Warnings:"
      @warnings.each do |warning|
        puts "  ⚠ #{warning}"
      end
      puts
    end

    if @errors.any?
      puts "Errors:"
      @errors.each do |error|
        puts "  ✗ #{error}"
      end
      puts
      puts "Validation FAILED with #{@errors.size} error(s) and #{@warnings.size} warning(s)"
    else
      puts "✓ All validations passed!"
      puts "  #{ICONS_CONFIG.size} icons validated successfully"
    end

    puts '=' * 80
  end
end

# Run validation if script is executed directly
IconValidator.new.validate! if __FILE__ == $PROGRAM_NAME
