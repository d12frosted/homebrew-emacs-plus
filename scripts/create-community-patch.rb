#!/usr/bin/env ruby
# frozen_string_literal: true

# Script to create a new community patch with proper structure
# Usage: ruby scripts/create-community-patch.rb

require 'json'
require 'fileutils'

REPO_ROOT = File.expand_path('..', __dir__)
COMMUNITY_DIR = File.join(REPO_ROOT, 'community')
PATCHES_DIR = File.join(COMMUNITY_DIR, 'patches')
REGISTRY_FILE = File.join(COMMUNITY_DIR, 'registry.json')

SUPPORTED_VERSIONS = %w[29 30 31].freeze

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

def prompt_versions
  puts "\nSupported Emacs versions: #{SUPPORTED_VERSIONS.join(', ')}"
  puts "Enter versions this patch supports (comma-separated, or 'all'):"
  input = prompt('Versions', default: 'all')

  if input.downcase == 'all'
    SUPPORTED_VERSIONS.dup
  else
    versions = input.split(',').map(&:strip)
    invalid = versions - SUPPORTED_VERSIONS
    unless invalid.empty?
      puts "Warning: Invalid versions ignored: #{invalid.join(', ')}"
    end
    versions & SUPPORTED_VERSIONS
  end
end

def validate_name(name)
  unless name.match?(/\A[a-z0-9][a-z0-9-]*[a-z0-9]\z/) || name.match?(/\A[a-z0-9]\z/)
    puts "Error: Name must be lowercase alphanumeric with hyphens (no leading/trailing hyphens)"
    return false
  end

  if Dir.exist?(File.join(PATCHES_DIR, name))
    puts "Error: Patch '#{name}' already exists"
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
  File.write(REGISTRY_FILE, JSON.pretty_generate(registry) + "\n")
end

def create_patch(name:, description:, maintainer:, versions:, homepage: nil)
  patch_dir = File.join(PATCHES_DIR, name)
  FileUtils.mkdir_p(patch_dir)

  # Create metadata.json
  metadata = {
    'name' => name,
    'description' => description,
    'maintainer' => maintainer,
    'homepage' => homepage,
    'compatibility' => {
      'emacs_versions' => versions
    },
    'created_at' => Time.now.strftime('%Y-%m-%d')
  }.compact

  File.write(
    File.join(patch_dir, 'metadata.json'),
    JSON.pretty_generate(metadata) + "\n"
  )

  # Create README.md
  readme_content = <<~README
    # #{name}

    #{description}

    ## Compatibility

    - Emacs versions: #{versions.join(', ')}

    ## Maintainer

    #{maintainer['github'] ? "[@#{maintainer['github']}](https://github.com/#{maintainer['github']})" : maintainer['name']}

    ## Usage

    Add to your `~/.config/emacs-plus/build.yml`:

    ```yaml
    patches:
      - #{name}
    ```

    Then rebuild Emacs:

    ```bash
    brew reinstall emacs-plus@30
    ```

    ## Patch Files

    #{versions.map { |v| "- `emacs-#{v}.patch` - Patch for Emacs #{v}" }.join("\n")}
  README

  File.write(File.join(patch_dir, 'README.md'), readme_content)

  # Create placeholder patch files
  versions.each do |ver|
    patch_file = File.join(patch_dir, "emacs-#{ver}.patch")
    File.write(patch_file, <<~PATCH)
      # Patch for Emacs #{ver}
      # Replace this with your actual patch content
      #
      # Generate with: git diff > emacs-#{ver}.patch
      # Or: diff -u original.c modified.c > emacs-#{ver}.patch
    PATCH
  end

  # Update registry
  registry = load_registry
  registry['patches'][name] = {
    'directory' => "patches/#{name}"
  }
  save_registry(registry)

  patch_dir
end

def main
  puts "=" * 60
  puts "Create Community Patch for emacs-plus"
  puts "=" * 60
  puts

  # Get patch name
  name = nil
  loop do
    name = prompt('Patch name (lowercase, alphanumeric, hyphens)')
    break if name && validate_name(name)
  end

  # Get description
  description = prompt('Short description')
  unless description && !description.empty?
    puts "Error: Description is required"
    exit 1
  end

  # Get maintainer (as object, matching icon format)
  github_user = prompt('Maintainer GitHub username (leave blank if no GitHub)')
  maintainer = if github_user && !github_user.empty?
                 { 'github' => github_user }
               else
                 name = prompt('Maintainer name')
                 unless name && !name.empty?
                   puts "Error: Either GitHub username or name is required"
                   exit 1
                 end
                 { 'name' => name }
               end

  # Get homepage (optional)
  homepage = prompt('Homepage URL (optional, press Enter to skip)')
  homepage = nil if homepage&.empty?

  # Get supported versions
  versions = prompt_versions
  if versions.empty?
    puts "Error: At least one version must be supported"
    exit 1
  end

  puts
  maintainer_display = maintainer['github'] ? "@#{maintainer['github']}" : maintainer['name']
  puts "Creating patch with:"
  puts "  Name: #{name}"
  puts "  Description: #{description}"
  puts "  Maintainer: #{maintainer_display}"
  puts "  Homepage: #{homepage || '(none)'}"
  puts "  Versions: #{versions.join(', ')}"
  puts

  unless prompt_yes_no('Proceed?')
    puts "Aborted."
    exit 0
  end

  patch_dir = create_patch(
    name: name,
    description: description,
    maintainer: maintainer,
    versions: versions,
    homepage: homepage
  )

  puts
  puts "=" * 60
  puts "Patch created successfully!"
  puts "=" * 60
  puts
  puts "Directory: #{patch_dir}"
  puts
  puts "Next steps:"
  puts "1. Add your patch files:"
  versions.each do |ver|
    puts "   - #{patch_dir}/emacs-#{ver}.patch"
  end
  puts
  puts "2. Test the patch:"
  puts "   echo 'patches:\\n  - #{name}' > ~/.config/emacs-plus/build.yml"
  puts "   make formula-30"
  puts
  puts "3. Submit a PR to add your patch to the community registry"
end

main if __FILE__ == $PROGRAM_NAME
