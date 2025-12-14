require_relative "UrlResolver"
require_relative "Icons"

class CopyDownloadStrategy < AbstractFileDownloadStrategy
  def initialize(url, name, version, **meta)
    @cached_location = Pathname.new url
  end
end

class EmacsBase < Formula
  def self.init version
    @@urlResolver = UrlResolver.new(version, ENV["HOMEBREW_EMACS_PLUS_MODE"] || "remote")
    # Capture formula_root at class load time (before Homebrew changes working directory)
    @@formula_root = begin
      tap = Tap.fetch(TAP_OWNER, TAP_REPO)
      ENV["HOMEBREW_EMACS_PLUS_MODE"] == "local" || !tap.installed? ?
        Dir.pwd : tap.path.to_s
    end
  end

  def self.local_patch(name, sha:)
    patch do
      url (@@urlResolver.patch_url name), :using => CopyDownloadStrategy
      sha256 sha
    end
  end

  def self.inject_icon_options
    ICONS_CONFIG.each do |icon, sha|
      option "with-#{icon}-icon", "Using Emacs #{icon} icon"
      next if build.without? "#{icon}-icon"
      resource "#{icon}-icon" do
        url (@@urlResolver.icon_url icon), :using => CopyDownloadStrategy
        sha256 sha
      end
    end
  end

  # ============================================================
  # Community Patches & Icons System
  # ============================================================

  def custom_config
    @custom_config ||= load_custom_config
  end

  def load_custom_config
    require 'yaml'
    require 'etc'
    config = {}
    config_source = nil

    # Get real home directory (Homebrew sandboxes HOME to a temp dir)
    real_home = Etc.getpwuid.dir

    if ENV["HOMEBREW_EMACS_PLUS_BUILD_CONFIG"]
      path = File.expand_path(ENV["HOMEBREW_EMACS_PLUS_BUILD_CONFIG"])
      if File.exist?(path)
        config = YAML.load_file(path)
        config_source = path
      end
    else
      # Use real home directory, not sandboxed HOME
      paths = [
        "#{real_home}/.config/emacs-plus/build.yml",
        "#{real_home}/.emacs-plus-build.yml"
      ]
      config_file = paths.find { |p| File.exist?(p) }
      if config_file
        config = YAML.load_file(config_file)
        config_source = config_file
      end
    end

    if config_source
      ohai "Loaded build config from: #{config_source}"
    end

    config
  end

  def registry
    @registry ||= begin
      require 'json'
      registry_file = "#{formula_root}/community/registry.json"
      File.exist?(registry_file) ? JSON.parse(File.read(registry_file)) : { "patches" => {}, "icons" => {} }
    end
  end

  def self.formula_root
    @@formula_root
  end

  def formula_root
    @@formula_root
  end

  def resolve_patches
    return [] unless custom_config["patches"]

    custom_config["patches"].map do |patch_ref|
      case patch_ref
      when String
        resolve_registry_patch(patch_ref)
      when Hash
        name = patch_ref.keys.first
        spec = patch_ref[name]
        odie "External patch '#{name}' requires 'url' and 'sha256'" unless spec["url"] && spec["sha256"]
        { name: name, url: spec["url"], sha256: spec["sha256"], type: "external" }
      else
        odie "Invalid patch specification: #{patch_ref}"
      end
    end
  end

  def resolve_registry_patch(name)
    info = registry.dig("patches", name)
    odie "Unknown community patch: #{name}\nCheck community/registry.json for available patches" unless info

    patch_dir = "#{formula_root}/community/#{info['directory']}"
    metadata_file = "#{patch_dir}/metadata.json"
    odie "Missing metadata for patch: #{name}" unless File.exist?(metadata_file)

    metadata = JSON.parse(File.read(metadata_file))

    emacs_ver = version.to_s.split(".").first
    unless metadata["compatibility"]["emacs_versions"].include?(emacs_ver)
      odie <<~ERROR
        Patch '#{name}' does not support Emacs #{emacs_ver}
        Supported versions: #{metadata["compatibility"]["emacs_versions"].join(", ")}
        Maintainer: @#{metadata["maintainer"]["github"]}
      ERROR
    end

    patch_file = "#{patch_dir}/emacs-#{emacs_ver}.patch"
    odie "Missing patch file: #{patch_file}" unless File.exist?(patch_file)

    { name: name, path: patch_file, type: "community", metadata: metadata }
  end

  def resolve_icon
    return nil unless custom_config["icon"]

    icon_ref = custom_config["icon"]
    case icon_ref
    when String
      resolve_registry_icon(icon_ref)
    when Hash
      odie "External icon requires 'url' and 'sha256'" unless icon_ref["url"] && icon_ref["sha256"]
      { url: icon_ref["url"], sha256: icon_ref["sha256"], type: "external" }
    else
      odie "Invalid icon specification"
    end
  end

  def resolve_registry_icon(name)
    # First check community registry
    info = registry.dig("icons", name)
    if info
      icon_dir = "#{formula_root}/community/#{info['directory']}"
      icon_file = "#{icon_dir}/icon.icns"
      odie "Missing icon file: #{icon_file}" unless File.exist?(icon_file)

      metadata_file = "#{icon_dir}/metadata.json"
      metadata = File.exist?(metadata_file) ? JSON.parse(File.read(metadata_file)) : {}

      return { name: name, path: icon_file, type: "community", metadata: metadata }
    end

    # Fallback to legacy icons (during deprecation period)
    if ICONS_CONFIG.key?(name)
      legacy_icon_path = "#{formula_root}/icons/#{name}.icns"
      if File.exist?(legacy_icon_path)
        ohai "Using legacy icon: #{name} (will be migrated to community registry)"
        return { name: name, path: legacy_icon_path, type: "legacy" }
      end
    end

    odie "Unknown icon: #{name}\nCheck community/registry.json or icons/ directory for available icons"
  end

  def check_deprecated_icon_option
    # Find if any deprecated --with-*-icon option is being used
    used_icon = ICONS_CONFIG.keys.find { |icon| build.with? "#{icon}-icon" }
    return unless used_icon

    require 'etc'

    real_home = Etc.getpwuid.dir
    deprecation_date = "2026-03-14"

    config_paths = [
      "#{real_home}/.config/emacs-plus/build.yml",
      "#{real_home}/.emacs-plus-build.yml"
    ]
    existing_config = config_paths.find { |p| File.exist?(p) }

    opoo "Icon options (--with-*-icon) are deprecated and will be removed on #{deprecation_date}"
    puts

    if existing_config
      # Config exists - show migration instructions
      puts "Please add the following to #{existing_config}:"
      puts
      puts "  icon: #{used_icon}"
      puts
      puts "Then reinstall without the --with-#{used_icon}-icon option."
    else
      # No config - show creation instructions
      # Note: Can't auto-migrate due to Homebrew's sandbox
      puts "Please create ~/.config/emacs-plus/build.yml with:"
      puts
      puts "  icon: #{used_icon}"
      puts
      puts "Then reinstall without the --with-#{used_icon}-icon option."
    end
    puts
  end

  def validate_custom_config
    config = custom_config
    return if config.empty?

    errors = []

    # Validate patches
    if config["patches"]
      unless config["patches"].is_a?(Array)
        errors << "'patches' must be an array"
      end
    end

    # Validate icon
    if config["icon"]
      case config["icon"]
      when String
        # Validate icon exists (community or legacy)
        name = config["icon"]
        unless registry.dig("icons", name) || ICONS_CONFIG.key?(name)
          available = ICONS_CONFIG.keys.first(5).join(", ")
          errors << "Unknown icon '#{name}'. Available legacy icons: #{available}..."
        end
      when Hash
        unless config["icon"]["url"] && config["icon"]["sha256"]
          errors << "External icon requires 'url' and 'sha256'"
        end
      else
        errors << "'icon' must be a string or hash with url/sha256"
      end
    end

    unless errors.empty?
      error_msg = "build.yml validation failed:\n" + errors.map { |e| "  - #{e}" }.join("\n")
      raise error_msg
    end

    ohai "Build config validated successfully"
  end

  def apply_custom_patches
    ohai "Checking for custom patches..."
    patches = resolve_patches
    if patches.empty?
      puts "  No custom patches configured"
      return
    end

    require 'digest'
    require 'tempfile'

    ohai "Applying custom patches"
    patches.each do |patch|
      puts "  - #{patch[:name]} (#{patch[:type]})"

      if patch[:type] == "community"
        if patch[:metadata] && patch[:metadata]["maintainer"]
          puts "    Maintainer: @#{patch[:metadata]["maintainer"]["github"]}"
        end
        system "patch", "-p1", "-i", patch[:path]
        odie "Failed to apply community patch: #{patch[:name]}" unless $?.success?
      else
        # External: download with curl, verify SHA256
        tmpfile = Tempfile.new(["patch-#{patch[:name]}-", ".patch"])
        system "curl", "-fsSL", "-o", tmpfile.path, patch[:url]
        odie "Failed to download external patch: #{patch[:name]}" unless $?.success?

        actual_sha = Digest::SHA256.file(tmpfile.path).hexdigest
        if actual_sha != patch[:sha256]
          odie <<~ERROR
            SHA256 mismatch for external patch: #{patch[:name]}
            Expected: #{patch[:sha256]}
            Actual:   #{actual_sha}
          ERROR
        end

        system "patch", "-p1", "-i", tmpfile.path
        odie "Failed to apply external patch: #{patch[:name]}" unless $?.success?
        tmpfile.unlink
      end
    end
  end

  def apply_custom_icon(icons_dir)
    icon = resolve_icon
    return unless icon

    require 'digest'
    require 'tempfile'
    require 'fileutils'

    ohai "Applying custom icon: #{icon[:name] || 'external'}"

    target_icon = "#{icons_dir}/Emacs.icns"

    case icon[:type]
    when "community", "legacy"
      if icon[:metadata] && icon[:metadata]["maintainer"]
        puts "  Maintainer: @#{icon[:metadata]["maintainer"]["github"]}"
      end
      puts "  Copying #{icon[:path]} -> #{target_icon}"
      FileUtils.rm_f(target_icon)
      FileUtils.cp(icon[:path], target_icon)
    when "external"
      # External: download with curl, verify SHA256
      tmpfile = Tempfile.new(["icon-", ".icns"])
      system "curl", "-fsSL", "-o", tmpfile.path, icon[:url]
      odie "Failed to download external icon" unless $?.success?

      actual_sha = Digest::SHA256.file(tmpfile.path).hexdigest
      if actual_sha != icon[:sha256]
        odie <<~ERROR
          SHA256 mismatch for external icon
          Expected: #{icon[:sha256]}
          Actual:   #{actual_sha}
        ERROR
      end

      FileUtils.rm_f(target_icon)
      FileUtils.cp(tmpfile.path, target_icon)
      tmpfile.unlink
    else
      odie "Unknown icon type: #{icon[:type]}"
    end
    puts "  Icon applied successfully"
  end

  # ============================================================
  # PATH Injection
  # ============================================================

  def path_injection_snippet
    path = PATH.new(ORIGINAL_PATHS)

    # Escape single quotes for use within single-quoted shell string
    # Replace ' with '\'' (end quote, escaped quote, start quote)
    escaped_path = path.to_s.gsub("'", "'\\''")

    <<~EOS
      if [ -z "$EMACS_PLUS_NO_PATH_INJECTION" ]; then
        export PATH='#{escaped_path}'
      fi
    EOS
  end

  def inject_path
    ohai "Injecting PATH via wrapper script in Emacs.app/Contents/MacOS/Emacs"
    app = "#{prefix}/Emacs.app"
    emacs_binary = "#{app}/Contents/MacOS/Emacs"
    emacs_real = "#{app}/Contents/MacOS/Emacs-real"
    path = PATH.new(ORIGINAL_PATHS)

    puts "Creating wrapper script with following PATH value:"
    path.each_entry { |x|
      puts x
    }

    # Rename original binary
    File.rename(emacs_binary, emacs_real) unless File.exist?(emacs_real)

    # Create wrapper script with relative path for relocatability
    File.open(emacs_binary, "w") do |f|
      f.write <<~EOS
        #!/bin/sh
        #{path_injection_snippet.chomp}
        exec "$(dirname "$0")/Emacs-real" "$@"
      EOS
    end

    # Make executable
    File.chmod(0755, emacs_binary)
    system "touch '#{app}'"
  end

  def print_env
    ohai "Environment"
    ["CC",
     "CXX",
     "OBJC",
     "OBJCXX",
     "CFLAGS",
     "CXXFLAGS",
     "CPPFLAGS",
     "LDFLAGS",
     "SDKROOT",
     "MAKEFLAGS",
     "CMAKE_PREFIX_PATH",
     "CMAKE_FRAMEWORK_PATH",
     "PKG_CONFIG_PATH",
     "PKG_CONFIG_LIBDIR",
     "HOMEBREW_GIT",
     "ACLOCAL_PATH",
     "PATH",
     "CPATH",
    ].each { |key|
      puts "#{key}: #{ENV[key]}"
    }
  end

  def inject_protected_resources_usage_desc
    ohai "Injecting description for protected resources usage"
    app = "#{prefix}/Emacs.app"
    plist = "#{app}/Contents/Info.plist"

    system "/usr/libexec/PlistBuddy -c 'Add NSCameraUsageDescription string' '#{plist}'"
    system "/usr/libexec/PlistBuddy -c 'Set NSCameraUsageDescription Emacs requires permission to access the Camera.' '#{plist}'"
    system "/usr/libexec/PlistBuddy -c 'Add NSMicrophoneUsageDescription string' '#{plist}'"
    system "/usr/libexec/PlistBuddy -c 'Set NSMicrophoneUsageDescription Emacs requires permission to access the Microphone.' '#{plist}'"
    system "/usr/libexec/PlistBuddy -c 'Add NSSpeechRecognitionUsageDescription string' '#{plist}' || true"
    system "/usr/libexec/PlistBuddy -c 'Set NSSpeechRecognitionUsageDescription Emacs requires permission to handle any speech recognition.' '#{plist}' || true"
    system "touch '#{app}'"
  end

  # Helper method to add or set a plist key (handles both cases)
  def plist_set(plist, key, type, value)
    # Try to add first; if it exists, set it instead
    # Use double quotes for the command to allow proper escaping
    escaped_value = value.to_s.gsub('"', '\\"')
    system "/usr/libexec/PlistBuddy -c \"Add :#{key} #{type} #{escaped_value}\" \"#{plist}\" 2>/dev/null || /usr/libexec/PlistBuddy -c \"Set :#{key} #{escaped_value}\" \"#{plist}\""
  end

  def create_emacs_client_app(icons_dir)
    ohai "Creating Emacs Client.app"

    # Prepare PATH for injection into AppleScript
    path = PATH.new(ORIGINAL_PATHS)
    escaped_path = path.to_s.gsub("'", "'\\''")

    # Create AppleScript source
    client_script = buildpath/"emacs-client.applescript"
    client_script.write <<~EOS
      -- Emacs Client AppleScript Application
      -- Handles opening files from Finder, drag-and-drop, and launching from Spotlight/Dock

      on open theDropped
        repeat with oneDrop in theDropped
          set dropPath to quoted form of POSIX path of oneDrop
          set pathInjection to system attribute "EMACS_PLUS_NO_PATH_INJECTION"
          if pathInjection is "" then
            set pathEnv to "PATH='#{escaped_path}' "
          else
            set pathEnv to ""
          end if
          try
            do shell script pathEnv & "#{prefix}/bin/emacsclient -c -a '' -n " & dropPath
          end try
        end repeat
        tell application "Emacs" to activate
      end open

      -- Handle launch without files (from Spotlight, Dock, or Finder)
      on run
        set pathInjection to system attribute "EMACS_PLUS_NO_PATH_INJECTION"
        if pathInjection is "" then
          set pathEnv to "PATH='#{escaped_path}' "
        else
          set pathEnv to ""
        end if
        try
          do shell script pathEnv & "#{prefix}/bin/emacsclient -c -a '' -n"
        end try
        tell application "Emacs" to activate
      end run
    EOS

    # Compile AppleScript to application bundle
    system "osacompile", "-o", buildpath/"nextstep/Emacs Client.app", client_script

    # Update Info.plist with proper metadata
    client_plist = buildpath/"nextstep/Emacs Client.app/Contents/Info.plist"
    plist_set client_plist, "CFBundleIdentifier", "string", "org.gnu.EmacsClient"
    plist_set client_plist, "CFBundleName", "string", "Emacs Client"
    plist_set client_plist, "CFBundleDisplayName", "string", "Emacs Client"
    plist_set client_plist, "CFBundleGetInfoString", "string", "Emacs Client #{version}"
    plist_set client_plist, "CFBundleVersion", "string", "#{version}"
    plist_set client_plist, "CFBundleShortVersionString", "string", "#{version}"
    plist_set client_plist, "LSApplicationCategoryType", "string", "public.app-category.productivity"
    plist_set client_plist, "NSHumanReadableCopyright", "string", "Copyright © 1989-#{Time.now.year} Free Software Foundation, Inc."

    # Add document types for file associations
    # CFBundleDocumentTypes might already exist from osacompile, delete and recreate
    system "/usr/libexec/PlistBuddy -c 'Delete :CFBundleDocumentTypes' '#{client_plist}' 2>/dev/null || true"
    system "/usr/libexec/PlistBuddy", "-c", "Add :CFBundleDocumentTypes array", client_plist
    system "/usr/libexec/PlistBuddy", "-c", "Add :CFBundleDocumentTypes:0 dict", client_plist
    system "/usr/libexec/PlistBuddy", "-c", "Add :CFBundleDocumentTypes:0:CFBundleTypeRole string Editor", client_plist
    system "/usr/libexec/PlistBuddy", "-c", "Add :CFBundleDocumentTypes:0:CFBundleTypeName string 'Text Document'", client_plist
    system "/usr/libexec/PlistBuddy", "-c", "Add :CFBundleDocumentTypes:0:LSItemContentTypes array", client_plist
    system "/usr/libexec/PlistBuddy", "-c", "Add :CFBundleDocumentTypes:0:LSItemContentTypes:0 string public.text", client_plist
    system "/usr/libexec/PlistBuddy", "-c", "Add :CFBundleDocumentTypes:0:LSItemContentTypes:1 string public.plain-text", client_plist
    system "/usr/libexec/PlistBuddy", "-c", "Add :CFBundleDocumentTypes:0:LSItemContentTypes:2 string public.source-code", client_plist
    system "/usr/libexec/PlistBuddy", "-c", "Add :CFBundleDocumentTypes:0:LSItemContentTypes:3 string public.script", client_plist
    system "/usr/libexec/PlistBuddy", "-c", "Add :CFBundleDocumentTypes:0:LSItemContentTypes:4 string public.shell-script", client_plist
    system "/usr/libexec/PlistBuddy", "-c", "Add :CFBundleDocumentTypes:0:LSItemContentTypes:5 string public.data", client_plist

    # Install custom icon (replace osacompile's default droplet icon)
    client_resources_dir = buildpath/"nextstep/Emacs Client.app/Contents/Resources"

    # Use a simple filename without spaces to avoid quoting issues
    system "cp", icons_dir/"Emacs.icns", client_resources_dir/"applet.icns"

    # Remove default droplet resources created by osacompile
    system "rm", "-f", client_resources_dir/"droplet.icns"
    system "rm", "-f", client_resources_dir/"droplet.rsrc"

    # Remove Assets.car file - on macOS 26+, the system prioritizes icon images
    # from Assets.car over .icns files, so we must remove it to use our custom icon
    system "rm", "-f", client_resources_dir/"Assets.car"

    # Set icon file reference (use simple name without spaces)
    # Try Delete first in case osacompile set it, then Add
    system "/usr/libexec/PlistBuddy -c 'Delete :CFBundleIconFile' '#{client_plist}' 2>/dev/null || true"
    system "/usr/libexec/PlistBuddy", "-c", "Add :CFBundleIconFile string applet", client_plist

    # Verify the icon was set correctly
    icon_check = `/usr/libexec/PlistBuddy -c 'Print :CFBundleIconFile' '#{client_plist}' 2>&1`.strip
    ohai "Emacs Client.app icon set to: #{icon_check}"
  end
end
