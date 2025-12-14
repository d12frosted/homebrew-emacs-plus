#!/usr/bin/env ruby
# frozen_string_literal: true

# Script to create a new community icon with proper structure
# Usage: ruby scripts/create-community-icon.rb [icon.icns]

require 'json'
require 'fileutils'

REPO_ROOT = File.expand_path('..', __dir__)
COMMUNITY_DIR = File.join(REPO_ROOT, 'community')
ICONS_DIR = File.join(COMMUNITY_DIR, 'icons')
REGISTRY_FILE = File.join(COMMUNITY_DIR, 'registry.json')

def prompt(message, default: nil)
  print default ? "#{message} [#{default}]: " : "#{message}: "
  input = gets.chomp
  input.empty? ? default : input
end

def prompt_yes_no(message, default: true)
  default_str = default ? 'Y/n' : 'y/N'
  print "#{message} [#{default_str}]: "
  input = gets.chomp.downcase
  return default if input.empty?
  input == 'y' || input == 'yes'
end

def validate_name(name)
  unless name.match?(/\A[a-z0-9][a-z0-9-]*[a-z0-9]\z/) || name.match?(/\A[a-z0-9]\z/)
    puts "Error: Name must be lowercase alphanumeric with hyphens (no leading/trailing hyphens)"
    return false
  end

  if Dir.exist?(File.join(ICONS_DIR, name))
    puts "Error: Icon '#{name}' already exists"
    return false
  end

  true
end

def validate_icns_file(path)
  unless File.exist?(path)
    puts "Error: File not found: #{path}"
    return false
  end

  unless path.end_with?('.icns')
    puts "Error: File must be .icns format"
    return false
  end

  # Check if it's a valid icns file (magic number)
  magic = File.binread(path, 4)
  unless magic == 'icns'
    puts "Error: Invalid .icns file (bad magic number)"
    return false
  end

  true
end

def load_registry
  if File.exist?(REGISTRY_FILE)
    JSON.parse(File.read(REGISTRY_FILE))
  else
    { 'schema_version' => '1.0', 'patches' => {}, 'icons' => {} }
  end
end

def save_registry(registry)
  # Sort icons alphabetically
  sorted_icons = registry['icons'].sort.to_h
  registry['icons'] = sorted_icons
  File.write(REGISTRY_FILE, JSON.pretty_generate(registry) + "\n")
end

def create_icon(name:, description:, maintainer:, source_file:, homepage: nil, license: nil)
  icon_dir = File.join(ICONS_DIR, name)
  FileUtils.mkdir_p(icon_dir)

  # Copy icon file
  FileUtils.cp(source_file, File.join(icon_dir, 'icon.icns'))

  # Create metadata.json
  metadata = {
    'name' => name,
    'description' => description,
    'maintainer' => maintainer,
    'homepage' => homepage,
    'license' => license,
    'created_at' => Time.now.strftime('%Y-%m-%d')
  }.compact

  File.write(
    File.join(icon_dir, 'metadata.json'),
    JSON.pretty_generate(metadata) + "\n"
  )

  # Update registry
  registry = load_registry
  registry['icons'][name] = {
    'directory' => "icons/#{name}"
  }
  save_registry(registry)

  icon_dir
end

def main
  puts "=" * 60
  puts "Create Community Icon for emacs-plus"
  puts "=" * 60
  puts

  # Get source icon file
  source_file = ARGV[0]
  if source_file
    source_file = File.expand_path(source_file)
    unless validate_icns_file(source_file)
      exit 1
    end
    puts "Using icon file: #{source_file}"
  else
    loop do
      source_file = prompt('Path to .icns file')
      source_file = File.expand_path(source_file) if source_file
      break if source_file && validate_icns_file(source_file)
    end
  end

  puts

  # Suggest name from filename
  suggested_name = File.basename(source_file, '.icns').downcase.gsub(/[^a-z0-9-]/, '-').gsub(/-+/, '-').gsub(/^-|-$/, '')

  # Get icon name
  name = nil
  loop do
    name = prompt('Icon name (lowercase, alphanumeric, hyphens)', default: suggested_name)
    break if name && validate_name(name)
  end

  # Get description
  description = prompt('Short description', default: "#{name} icon for Emacs")
  unless description && !description.empty?
    puts "Error: Description is required"
    exit 1
  end

  # Get maintainer
  maintainer = prompt('Maintainer (name or GitHub username)')
  unless maintainer && !maintainer.empty?
    puts "Error: Maintainer is required"
    exit 1
  end

  # Get homepage (optional)
  homepage = prompt('Homepage URL (optional, press Enter to skip)')
  homepage = nil if homepage&.empty?

  # Get license (optional)
  license = prompt('License (e.g., MIT, CC-BY-4.0, optional)')
  license = nil if license&.empty?

  puts
  puts "Creating icon with:"
  puts "  Name: #{name}"
  puts "  Description: #{description}"
  puts "  Maintainer: #{maintainer}"
  puts "  Homepage: #{homepage || '(none)'}"
  puts "  License: #{license || '(none)'}"
  puts "  Source: #{source_file}"
  puts

  unless prompt_yes_no('Proceed?')
    puts "Aborted."
    exit 0
  end

  icon_dir = create_icon(
    name: name,
    description: description,
    maintainer: maintainer,
    source_file: source_file,
    homepage: homepage,
    license: license
  )

  puts
  puts "=" * 60
  puts "Icon created successfully!"
  puts "=" * 60
  puts
  puts "Directory: #{icon_dir}"
  puts
  puts "To use this icon, add to ~/.config/emacs-plus/build.yml:"
  puts
  puts "  icon: #{name}"
  puts
  puts "Then rebuild Emacs:"
  puts
  puts "  brew reinstall emacs-plus@30"
  puts
  puts "To submit to community registry, create a PR with:"
  puts "  - #{icon_dir}/icon.icns"
  puts "  - #{icon_dir}/metadata.json"
  puts "  - Updated community/registry.json"
end

main if __FILE__ == $PROGRAM_NAME
