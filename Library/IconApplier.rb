# frozen_string_literal: true

# Shared module for applying icons to Emacs.app and Emacs Client.app.
# Used by both the formula (post_install) and cask (postflight).

require 'fileutils'
require_relative 'BuildConfig'

module IconApplier
  class << self
    # Apply icon from build.yml to the given app paths
    # @param app_path [String, Pathname] Path to Emacs.app
    # @param client_app_path [String, Pathname, nil] Path to Emacs Client.app (optional)
    # @return [Boolean] true if icon was applied, false if no icon configured
    def apply(app_path, client_app_path = nil)
      app_path = app_path.to_s
      client_app_path = client_app_path&.to_s

      unless File.exist?(app_path)
        ohai "App not found: #{app_path}"
        return false
      end

      result = BuildConfig.load_config
      config = result[:config]

      if result[:source]
        ohai "Loaded build config from: #{result[:source]}"
      end

      icon = BuildConfig.resolve_icon(config)
      unless icon
        ohai "No custom icon configured in build.yml"
        return false
      end

      icons_dir = "#{app_path}/Contents/Resources"

      ohai "Applying icon from build.yml: #{icon[:name] || 'external'}"

      case icon[:type]
      when "community"
        apply_community_icon(icon, app_path, icons_dir)
        apply_to_client_app(icon, client_app_path) if client_app_path && File.exist?(client_app_path)
      when "external"
        apply_external_icon(icon, app_path, icons_dir)
      else
        puts "  Unknown icon type: #{icon[:type]}"
        return false
      end

      # Touch app to update Finder cache
      system "touch", app_path
      system "touch", client_app_path if client_app_path && File.exist?(client_app_path)

      puts "  Icon applied successfully"
      true
    end

    private

    def apply_community_icon(icon, app_path, icons_dir)
      maintainer_str = BuildConfig.format_maintainer(icon[:metadata]&.dig("maintainer"))
      puts "  Maintainer: #{maintainer_str}" if maintainer_str

      target_icon = "#{icons_dir}/Emacs.icns"
      target_assets = "#{icons_dir}/Assets.car"

      puts "  Copying #{icon[:path]} -> #{target_icon}"
      FileUtils.rm_f(target_icon)
      FileUtils.cp(icon[:path], target_icon)

      plist_path = "#{app_path}/Contents/Info.plist"

      if icon[:tahoe_path]
        puts "  Copying #{icon[:tahoe_path]} -> #{target_assets} (Tahoe)"
        FileUtils.rm_f(target_assets)
        FileUtils.cp(icon[:tahoe_path], target_assets)

        # Set CFBundleIconName for Tahoe
        tahoe_icon_name = icon[:metadata]&.dig("tahoe_icon_name") || "Emacs"
        if File.exist?(plist_path)
          puts "  Setting CFBundleIconName = #{tahoe_icon_name}"
          system "/usr/libexec/PlistBuddy -c 'Delete :CFBundleIconName' '#{plist_path}' 2>/dev/null || true"
          system "/usr/libexec/PlistBuddy", "-c", "Add :CFBundleIconName string #{tahoe_icon_name}", plist_path
        end
      else
        # Remove stale Assets.car if switching to non-Tahoe icon
        FileUtils.rm_f(target_assets) if File.exist?(target_assets)
        # Remove CFBundleIconName if present
        if File.exist?(plist_path)
          system "/usr/libexec/PlistBuddy -c 'Delete :CFBundleIconName' '#{plist_path}' 2>/dev/null || true"
        end
      end
    end

    def apply_to_client_app(icon, client_app_path)
      client_icons = "#{client_app_path}/Contents/Resources"
      client_plist = "#{client_app_path}/Contents/Info.plist"

      puts "  Updating Emacs Client.app icon..."
      FileUtils.rm_f("#{client_icons}/Emacs.icns")
      FileUtils.cp(icon[:path], "#{client_icons}/Emacs.icns")

      if icon[:tahoe_path]
        FileUtils.rm_f("#{client_icons}/Assets.car")
        FileUtils.cp(icon[:tahoe_path], "#{client_icons}/Assets.car")
        tahoe_icon_name = icon[:metadata]&.dig("tahoe_icon_name") || "Emacs"
        system "/usr/libexec/PlistBuddy -c 'Delete :CFBundleIconName' '#{client_plist}' 2>/dev/null || true"
        system "/usr/libexec/PlistBuddy", "-c", "Add :CFBundleIconName string #{tahoe_icon_name}", client_plist
      else
        FileUtils.rm_f("#{client_icons}/Assets.car")
        system "/usr/libexec/PlistBuddy -c 'Delete :CFBundleIconName' '#{client_plist}' 2>/dev/null || true"
      end
    end

    def apply_external_icon(icon, app_path, icons_dir)
      require 'digest'
      require 'open-uri'
      require 'tempfile'

      tmpfile = Tempfile.new(["icon-", ".icns"])
      begin
        puts "  Downloading external icon..."
        URI.open(icon[:url]) do |remote|
          tmpfile.write(remote.read)
        end
        tmpfile.close

        actual_sha = Digest::SHA256.file(tmpfile.path).hexdigest
        if actual_sha != icon[:sha256]
          puts "  ERROR: SHA256 mismatch!"
          puts "  Expected: #{icon[:sha256]}"
          puts "  Actual:   #{actual_sha}"
          return false
        end

        target_icon = "#{icons_dir}/Emacs.icns"
        target_assets = "#{icons_dir}/Assets.car"

        FileUtils.rm_f(target_icon)
        FileUtils.cp(tmpfile.path, target_icon)
        FileUtils.rm_f(target_assets)

        # Remove CFBundleIconName for external icons
        plist_path = "#{app_path}/Contents/Info.plist"
        if File.exist?(plist_path)
          system "/usr/libexec/PlistBuddy -c 'Delete :CFBundleIconName' '#{plist_path}' 2>/dev/null || true"
        end
      ensure
        tmpfile.unlink
      end
    end

    # Use Homebrew's ohai if available, otherwise plain puts
    def ohai(message)
      if defined?(Homebrew) && Homebrew.respond_to?(:ohai)
        Homebrew.ohai(message)
      elsif respond_to?(:super_ohai, true)
        super_ohai(message)
      else
        # Check if we're in Homebrew context where ohai is a method
        begin
          Kernel.send(:ohai, message)
        rescue NoMethodError
          puts "==> #{message}"
        end
      end
    end
  end
end
