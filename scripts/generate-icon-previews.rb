#!/usr/bin/env ruby
# frozen_string_literal: true

# Script to generate icon previews and update community/icons/README.md
# Usage: ruby scripts/generate-icon-previews.rb
#
# This script:
# 1. Generates preview.png (128x128) from icon.icns for any icon missing it
# 2. Regenerates community/icons/README.md with a visual gallery

require 'json'
require 'fileutils'

REPO_ROOT = File.expand_path('..', __dir__)
COMMUNITY_ICONS_DIR = File.join(REPO_ROOT, 'community', 'icons')
README_PATH = File.join(COMMUNITY_ICONS_DIR, 'README.md')
PREVIEW_SIZE = 128

class IconPreviewGenerator
  def initialize
    @icons = []
    @tahoe_icons = []
    @other_icons = []
    @generated = 0
    @skipped = 0
    @errors = []
  end

  def run
    puts "Generating icon previews..."
    puts

    collect_icons
    generate_previews
    generate_readme

    puts
    puts "=" * 60
    puts "Summary:"
    puts "  #{@icons.length} icons found"
    puts "    #{@tahoe_icons.length} Tahoe-compliant"
    puts "    #{@other_icons.length} standard"
    puts "  #{@generated} previews generated"
    puts "  #{@skipped} previews already existed"
    puts "  #{@errors.length} errors" if @errors.any?
    @errors.each { |e| puts "    - #{e}" }
    puts "=" * 60
  end

  private

  def collect_icons
    Dir.glob(File.join(COMMUNITY_ICONS_DIR, '*')).each do |dir|
      next unless File.directory?(dir)
      next if File.basename(dir).start_with?('.')

      icon_name = File.basename(dir)
      icon_file = File.join(dir, 'icon.icns')
      metadata_file = File.join(dir, 'metadata.json')
      preview_file = File.join(dir, 'preview.png')
      assets_car = File.join(dir, 'Assets.car')

      next unless File.exist?(icon_file)

      metadata = if File.exist?(metadata_file)
                   JSON.parse(File.read(metadata_file)) rescue {}
                 else
                   {}
                 end

      icon = {
        name: icon_name,
        dir: dir,
        icon_file: icon_file,
        metadata_file: metadata_file,
        preview_file: preview_file,
        metadata: metadata,
        tahoe: File.exist?(assets_car)
      }

      @icons << icon

      if icon[:tahoe]
        @tahoe_icons << icon
      else
        @other_icons << icon
      end
    end

    # Sort Tahoe icons and other icons alphabetically
    @tahoe_icons.sort_by! { |i| i[:name].downcase }
    @other_icons.sort_by! { |i| i[:name].downcase }
  end

  def generate_previews
    @icons.each do |icon|
      if File.exist?(icon[:preview_file])
        @skipped += 1
        next
      end

      print "  Generating preview for #{icon[:name]}... "

      result = system(
        'sips', '-s', 'format', 'png',
        '-z', PREVIEW_SIZE.to_s, PREVIEW_SIZE.to_s,
        icon[:icon_file],
        '--out', icon[:preview_file],
        out: File::NULL, err: File::NULL
      )

      if result && File.exist?(icon[:preview_file])
        puts "OK"
        @generated += 1
      else
        puts "FAILED"
        @errors << "Failed to generate preview for #{icon[:name]}"
      end
    end
  end

  def icon_row(icon)
    meta = icon[:metadata]
    name = icon[:name]

    # Author info
    maintainer = meta['maintainer'] || {}
    github = maintainer['github']
    author = if github
               "[#{github}](https://github.com/#{github})"
             else
               maintainer['name'] || 'Unknown'
             end

    # Source link
    homepage = meta['homepage']
    source = homepage ? "[Source](#{homepage})" : ''

    # Preview image (relative path from README location)
    preview_path = "#{name}/preview.png"

    "| ![#{name}](#{preview_path}) | `#{name}` | #{author} | #{source} |"
  end

  def generate_readme
    puts
    puts "Generating README.md..."

    content = <<~HEADER
      # Icons Gallery

      This directory contains community-maintained icons for Emacs+.

      ## Usage

      To use an icon, add it to your `~/.config/emacs-plus/build.yml`:

      ```yaml
      icon: icon-name
      ```

      For example:
      ```yaml
      icon: modern-doom
      ```

    HEADER

    # Tahoe-compliant icons section
    if @tahoe_icons.any?
      content += <<~TAHOE_HEADER
        ## macOS 26+ (Tahoe) Compliant Icons (#{@tahoe_icons.length})

        These icons include `Assets.car` for native macOS Tahoe support. They display
        properly without the "icon jail" effect and may react to system appearance changes.

        | Preview | Name | Author | Source |
        |:-------:|------|--------|--------|
      TAHOE_HEADER

      @tahoe_icons.each do |icon|
        content += icon_row(icon) + "\n"
      end

      content += "\n"
    end

    # Other icons section
    content += <<~OTHER_HEADER
      ## All Icons (#{@other_icons.length})

      Standard icons using `.icns` format. On macOS 26+, these may appear in "icon jail"
      (displayed smaller within a rounded square container).

      | Preview | Name | Author | Source |
      |:-------:|------|--------|--------|
    OTHER_HEADER

    @other_icons.each do |icon|
      content += icon_row(icon) + "\n"
    end

    content += <<~FOOTER

      ---

      ## Contributing

      See the [community README](../README.md) for instructions on adding new icons.

      ### Requirements

      Each icon must include:
      - `icon.icns` - The icon file (required)
      - `metadata.json` - Icon metadata (name, maintainer, homepage)
      - `preview.png` - 128x128 preview image

      #### Optional: macOS 26+ (Tahoe) Support

      For icons designed for macOS Tahoe's liquid glass aesthetic, you can also include:
      - `Assets.car` - Compiled asset catalog for Tahoe

      On macOS 26+, the system prioritizes `Assets.car` over `.icns` files. If your icon includes
      `Assets.car`, it will be used on Tahoe while the `.icns` provides fallback for older macOS versions.

      **Metadata fields for Tahoe icons:**
      - `tahoe_sha256` - SHA256 checksum of Assets.car (for verification)
      - `tahoe_icon_name` - Icon name inside Assets.car (defaults to "Emacs" if not specified)

      To create `Assets.car` from an `.icon` bundle, use Apple's `actool`:
      ```bash
      actool YourIcon.icon --compile output --app-icon YourIcon --enable-on-demand-resources NO \\
        --minimum-deployment-target 26.0 --platform macosx
      ```

      The `--app-icon` value becomes the icon name that should be set in `tahoe_icon_name`.

      To regenerate previews and this README, run:
      ```bash
      ruby scripts/generate-icon-previews.rb
      ```
    FOOTER

    File.write(README_PATH, content)
    puts "  Written to #{README_PATH}"
  end
end

if __FILE__ == $PROGRAM_NAME
  generator = IconPreviewGenerator.new
  generator.run
end
