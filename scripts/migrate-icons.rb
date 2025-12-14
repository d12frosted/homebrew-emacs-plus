#!/usr/bin/env ruby
# frozen_string_literal: true

# Script to migrate existing icons to community registry structure
# Run from repository root: ruby scripts/migrate-icons.rb

require 'json'
require 'fileutils'

# Load ICONS_CONFIG
require_relative '../Library/Icons'

REPO_ROOT = File.expand_path('..', __dir__)
ICONS_DIR = File.join(REPO_ROOT, 'icons')
COMMUNITY_ICONS_DIR = File.join(REPO_ROOT, 'community', 'icons')
REGISTRY_FILE = File.join(REPO_ROOT, 'community', 'registry.json')

# Derive maintainer from icon name where possible
def derive_maintainer(name)
  # Known maintainers based on icon naming patterns
  maintainers = {
    'cg433n' => 'cg433n',
    'asingh4242' => 'asingh4242',
    'azhilin' => 'azhilin',
    'bananxan' => 'bananxan',
    'mzaplotnik' => 'mzaplotnik',
    'sjrmanning' => 'sjrmanning',
    'nobu417' => 'nobu417',
    'savchenkovaleriy' => 'savchenkovaleriy',
    'c9rgreen' => 'c9rgreen',
    'elrumo' => 'elrumo',
    'bokehlicia' => 'bokehlicia',
    'alecive' => 'alecive',
    'lds56' => 'lds56',
  }

  maintainers.each do |pattern, github|
    return github if name.include?(pattern)
  end

  # Default maintainer for icons without clear attribution
  'd12frosted'
end

# Generate description from icon name
def generate_description(name)
  case name
  when /^EmacsIcon(\d+)$/
    "Classic Emacs icon variant #{$1}"
  when /^modern-doom3?$/
    "Doom-inspired Emacs icon"
  when /^modern-sexy-v(\d+)$/
    "Modern sexy Emacs icon variant #{$1}"
  when /^modern-pen/
    "Modern pen-style Emacs icon"
  when /^modern-black/
    "Modern black-themed Emacs icon"
  when /^modern-purple/
    "Modern purple Emacs icon"
  when /^modern-orange$/
    "Modern orange Emacs icon"
  when /^modern-yellow$/
    "Modern yellow Emacs icon"
  when /^modern-paper$/
    "Modern paper-style Emacs icon"
  when /^modern-papirus$/
    "Papirus-style Emacs icon"
  when /^modern-vscode$/
    "VS Code-inspired Emacs icon"
  when /^modern-nuvola$/
    "Nuvola-style Emacs icon"
  when /^modern$/
    "Modern Emacs icon"
  when /^retro/
    "Retro-style Emacs icon"
  when /^gnu-head$/
    "GNU head Emacs icon"
  when /^emacs-card/
    "Card-style Emacs icon"
  when /^spacemacs$/
    "Spacemacs icon"
  when /^dragon$/
    "Dragon Emacs icon"
  when /^cacodemon$/
    "Cacodemon (Doom) Emacs icon"
  when /^skamacs$/
    "Skamacs icon"
  when /big-sur/
    "macOS Big Sur-style Emacs icon"
  when /sonoma/
    "macOS Sonoma-style Emacs icon"
  when /memeplex/
    "Memeplex Emacs icon"
  else
    name.gsub('-', ' ').gsub(/modern\s+/, 'Modern ').capitalize + " Emacs icon"
  end
end

def migrate_icons
  puts "Migrating icons to community registry..."
  puts "Source: #{ICONS_DIR}"
  puts "Target: #{COMMUNITY_ICONS_DIR}"
  puts

  # Load existing registry
  registry = JSON.parse(File.read(REGISTRY_FILE))

  migrated = 0
  skipped = 0
  errors = []

  ICONS_CONFIG.each do |name, sha256|
    source_icon = File.join(ICONS_DIR, "#{name}.icns")
    target_dir = File.join(COMMUNITY_ICONS_DIR, name)
    target_icon = File.join(target_dir, 'icon.icns')
    target_metadata = File.join(target_dir, 'metadata.json')

    # Check if already migrated
    if File.exist?(target_icon)
      puts "  SKIP: #{name} (already exists)"
      skipped += 1
      next
    end

    # Check source exists
    unless File.exist?(source_icon)
      puts "  ERROR: #{name} - source not found: #{source_icon}"
      errors << name
      next
    end

    # Create directory
    FileUtils.mkdir_p(target_dir)

    # Copy icon
    FileUtils.cp(source_icon, target_icon)

    # Create metadata
    metadata = {
      'name' => name,
      'description' => generate_description(name),
      'maintainer' => {
        'github' => derive_maintainer(name)
      },
      'legacy_sha256' => sha256
    }
    File.write(target_metadata, JSON.pretty_generate(metadata) + "\n")

    # Add to registry
    registry['icons'][name] = {
      'directory' => "icons/#{name}"
    }

    puts "  OK: #{name}"
    migrated += 1
  end

  # Write updated registry
  File.write(REGISTRY_FILE, JSON.pretty_generate(registry) + "\n")

  puts
  puts "Migration complete:"
  puts "  Migrated: #{migrated}"
  puts "  Skipped:  #{skipped}"
  puts "  Errors:   #{errors.length}"

  if errors.any?
    puts
    puts "Icons with errors:"
    errors.each { |e| puts "  - #{e}" }
    exit 1
  end
end

migrate_icons if __FILE__ == $PROGRAM_NAME
