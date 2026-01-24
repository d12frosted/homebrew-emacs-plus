require_relative "UrlResolver"
require_relative "BuildConfig"

class CopyDownloadStrategy < AbstractFileDownloadStrategy
  def initialize(url, name, version, **meta)
    super
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

  # Read revision from build.yml at class definition time
  # Returns revision string for given version, or nil if not set
  # Note: This runs at class load time, so we silently ignore config errors here.
  # The error will be shown with full details when the formula actually runs.
  def self.revision_from_config(version)
    begin
      result = BuildConfig.load_config
      config = result[:config]
      return nil unless config["revision"]

      revision = config["revision"]
      # Support both: revision: "abc" (single) or revision: { "30": "abc" } (versioned)
      if revision.is_a?(Hash)
        # Try both string and integer keys
        revision[version.to_s] || revision[version]
      else
        # Single revision applies to all versions (not recommended but supported)
        revision
      end
    rescue BuildConfig::ConfigurationError
      # Silently ignore - error will be shown with full context during formula run
      nil
    rescue
      # Silently ignore other errors at class load time
      nil
    end
  end

  # ============================================================
  # Community Patches & Icons System
  # ============================================================

  def custom_config
    @custom_config ||= load_custom_config
  end

  def custom_config_source
    @custom_config_source
  end

  def load_custom_config
    result = BuildConfig.load_config
    @custom_config_source = result[:source]

    if result[:source]
      ohai "Loaded build config from: #{result[:source]}"
      BuildConfig.print_config(result[:config], result[:source], context: :formula, output: method(:puts))
    end

    result[:config]
  end

  def registry
    @registry ||= BuildConfig.registry
  end

  # Format maintainer for display - delegate to BuildConfig
  def format_maintainer(maintainer)
    BuildConfig.format_maintainer(maintainer)
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
      maintainer_str = format_maintainer(metadata["maintainer"]) || "Unknown"
      odie <<~ERROR
        Patch '#{name}' does not support Emacs #{emacs_ver}
        Supported versions: #{metadata["compatibility"]["emacs_versions"].join(", ")}
        Maintainer: #{maintainer_str}
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
    info = registry.dig("icons", name)
    odie "Unknown icon: #{name}\nCheck community/registry.json for available icons" unless info

    icon_dir = "#{formula_root}/community/#{info['directory']}"
    icon_file = "#{icon_dir}/icon.icns"
    odie "Missing icon file: #{icon_file}" unless File.exist?(icon_file)

    metadata_file = "#{icon_dir}/metadata.json"
    metadata = File.exist?(metadata_file) ? JSON.parse(File.read(metadata_file)) : {}

    # Check for Tahoe Assets.car (macOS 26+)
    assets_car = "#{icon_dir}/Assets.car"
    tahoe_path = File.exist?(assets_car) ? assets_car : nil

    { name: name, path: icon_file, tahoe_path: tahoe_path, type: "community", metadata: metadata }
  end

  def check_icon_compatibility
    # Check if icon is configured for non-Cocoa builds
    return if (build.with? "cocoa") && (build.without? "x11")

    # Check for icon in build.yml config
    config = custom_config
    if config["icon"]
      odie "Icon configuration in build.yml is not compatible with --with-x11 or --without-cocoa. " \
           "These build configurations do not produce Emacs.app."
    end
  end

  def check_pinned_revision(version)
    # Check for revision from build.yml config
    config = custom_config
    if config["revision"]
      revision = if config["revision"].is_a?(Hash)
        config["revision"][version.to_s] || config["revision"][version]
      else
        config["revision"]
      end

      if revision
        ohai "Building from pinned revision (via build.yml)"
        puts "  Revision: #{revision}"
        puts "  To use the latest commit, remove 'revision' from your build.yml"
        puts
        return
      end
    end

    # Check for revision from environment variable (deprecated)
    env_var = "HOMEBREW_EMACS_PLUS_#{version}_REVISION"
    revision = ENV[env_var]
    return unless revision

    opoo "Building from pinned revision via #{env_var}"
    puts "  Revision: #{revision}"
    puts
    puts "  WARNING: Environment variable configuration is deprecated."
    puts "  Please migrate to build.yml by adding:"
    puts
    puts "    revision:"
    puts "      \"#{version}\": #{revision}"
    puts
    puts "  to ~/.config/emacs-plus/build.yml, then unset the variable:"
    puts "    unset #{env_var}"
    puts
  end

  def validate_custom_config
    config = custom_config
    return if config.empty?

    # BuildConfig already validated syntax and types during load_config
    # Here we do additional formula-specific validation (e.g., icon exists in registry)
    errors = []

    # Validate icon exists in registry (if it's a string reference)
    if config["icon"].is_a?(String)
      name = config["icon"]
      unless registry.dig("icons", name)
        errors << "Unknown icon '#{name}'. Check community/registry.json for available icons."
      end
    end

    # Validate patches exist in registry (if they're string references)
    if config["patches"].is_a?(Array)
      config["patches"].each do |patch_ref|
        next unless patch_ref.is_a?(String)
        unless registry.dig("patches", patch_ref)
          errors << "Unknown patch '#{patch_ref}'. Check community/registry.json for available patches."
        end
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
        maintainer_str = format_maintainer(patch[:metadata]&.dig("maintainer"))
        puts "    Maintainer: #{maintainer_str}" if maintainer_str
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
      maintainer_str = format_maintainer(icon[:metadata]&.dig("maintainer"))
      puts "  Maintainer: #{maintainer_str}" if maintainer_str
      puts "  Copying #{icon[:path]} -> #{target_icon}"
      FileUtils.rm_f(target_icon)
      FileUtils.cp(icon[:path], target_icon)

      # Copy Tahoe Assets.car if available (macOS 26+)
      if icon[:tahoe_path]
        target_assets = "#{icons_dir}/Assets.car"
        puts "  Copying #{icon[:tahoe_path]} -> #{target_assets} (Tahoe)"
        FileUtils.rm_f(target_assets)
        FileUtils.cp(icon[:tahoe_path], target_assets)

        # Set CFBundleIconName in plist for Tahoe icon selection
        # Icon name comes from metadata, defaults to "Emacs"
        tahoe_icon_name = icon[:metadata]&.dig("tahoe_icon_name") || "Emacs"
        plist_path = File.expand_path("../Info.plist", icons_dir)
        if File.exist?(plist_path)
          puts "  Setting CFBundleIconName = #{tahoe_icon_name}"
          system "/usr/libexec/PlistBuddy -c 'Delete :CFBundleIconName' '#{plist_path}' 2>/dev/null || true"
          system "/usr/libexec/PlistBuddy", "-c", "Add :CFBundleIconName string #{tahoe_icon_name}", plist_path
        end
      end
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

  # Apply icon during post_install (for quick testing without rebuild)
  # Call this from post_install to re-apply icon from build.yml
  def apply_icon_post_install
    require_relative 'IconApplier'
    IconApplier.apply(prefix/"Emacs.app", prefix/"Emacs Client.app")
  end

  # ============================================================
  # PATH Injection via LSEnvironment
  # ============================================================

  # Check if user PATH injection is enabled (default: true)
  def inject_path?
    config = custom_config
    !config.key?("inject_path") || config["inject_path"]
  end

  # Build the base PATH for native compilation (always included first)
  def native_comp_path
    # Use Homebrew's detected prefix
    prefix_path = HOMEBREW_PREFIX.to_s
    [
      "#{prefix_path}/bin",
      "#{prefix_path}/sbin",
      "/usr/bin",
      "/bin",
      "/usr/sbin",
      "/sbin",
    ].join(":")
  end

  # Build the full PATH value for injection
  # User PATH comes first (preserving order), native comp paths appended if missing
  def build_path
    if inject_path?
      user_path = PATH.new(ORIGINAL_PATHS).to_s
      if user_path && !user_path.empty?
        user_parts = user_path.split(':')
        native_parts = native_comp_path.split(':')
        missing_native = native_parts.reject { |p| user_parts.include?(p) }
        return missing_native.empty? ? user_path : "#{user_path}:#{missing_native.join(':')}"
      end
    end
    native_comp_path
  end

  # Find the gcc version number (e.g., "15")
  def gcc_version
    Dir.glob("#{HOMEBREW_PREFIX}/bin/gcc-*").map do |path|
      File.basename(path).sub("gcc-", "")
    end.select { |v| v.match?(/^\d+$/) }.max
  end

  # Find the directory containing libemutls_w.a
  def find_emutls_dir
    gcc_cellar = "#{HOMEBREW_PREFIX}/Cellar/gcc"
    return nil unless File.directory?(gcc_cellar)

    emutls_files = Dir.glob("#{gcc_cellar}/**/libemutls_w.a")
    return nil if emutls_files.empty?

    File.dirname(emutls_files.first)
  end

  # Build LIBRARY_PATH for native compilation
  def build_library_path
    paths = []

    # Add emutls directory (critical for native compilation)
    emutls_dir = find_emutls_dir
    paths << emutls_dir if emutls_dir

    # Add gcc library directories
    paths << "#{HOMEBREW_PREFIX}/lib/gcc/current"
    paths << "#{HOMEBREW_PREFIX}/lib"

    paths.compact.join(":")
  end

  def inject_emacs_plus_site_lisp(major_version)
    # Install to Homebrew's shared site-lisp directory
    # Emacs looks here for site-start.el at startup
    site_lisp_dir = "#{share}/emacs/site-lisp"

    ohai "Creating Emacs Plus site-lisp with ns-emacs-plus-version = #{major_version}"

    # Create site-lisp directory
    FileUtils.mkdir_p(site_lisp_dir)

    # Create site-start.el with the version variable and PATH injection code
    File.open("#{site_lisp_dir}/site-start.el", "w") do |f|
      f.write <<~EOS
        ;;; site-start.el --- Emacs Plus site initialization -*- lexical-binding: t -*-

        ;; This file is automatically generated by emacs-plus.
        ;; It defines variables to identify this as an Emacs Plus build.

        (defconst ns-emacs-plus-version #{major_version}
          "Major version of Emacs Plus that built this Emacs.
        This can be used to detect Emacs Plus in your init.el:

          (when (bound-and-true-p ns-emacs-plus-version)
            ;; Emacs Plus specific configuration
            )")

        ;; PATH injection via EMACS_PLUS_PATH
        ;; macOS blocks PATH in LSEnvironment for security reasons, so we store
        ;; the desired PATH in EMACS_PLUS_PATH and apply it here at startup.
        (defconst ns-emacs-plus-injected-path
          (not (null (getenv "EMACS_PLUS_PATH")))
          "Non-nil if PATH was injected by Emacs Plus at install time.
        When this is t, you can skip exec-path-from-shell-initialize:

          (unless (bound-and-true-p ns-emacs-plus-injected-path)
            (exec-path-from-shell-initialize))")

        (when-let ((emacs-plus-path (getenv "EMACS_PLUS_PATH")))
          ;; Set exec-path for Emacs to find executables
          (setq exec-path (append (split-string emacs-plus-path ":" t)
                                  (list exec-directory)))
          ;; Set PATH in process-environment for subprocesses
          (setenv "PATH" emacs-plus-path))

        (provide 'emacs-plus)

        ;;; site-start.el ends here
      EOS
    end
  end

  def inject_path
    app = "#{prefix}/Emacs.app"
    plist = "#{app}/Contents/Info.plist"

    if inject_path?
      ohai "Injecting native compilation environment and user PATH into #{app}"
    else
      ohai "Injecting native compilation environment into #{app}"
    end

    # Add LSEnvironment dict
    system("/usr/libexec/PlistBuddy", "-c", "Add :LSEnvironment dict", plist)

    # EMACS_PLUS_PATH: Only set when inject_path is enabled
    # macOS blocks PATH in LSEnvironment for security reasons, so we use
    # a custom env var that site-start.el reads to set exec-path and PATH
    if inject_path?
      path = build_path
      puts "EMACS_PLUS_PATH value:"
      path.split(':').each { |p| puts "  #{p}" }
      system("/usr/libexec/PlistBuddy", "-c", "Add :LSEnvironment:EMACS_PLUS_PATH string '#{path}'", plist)
    end

    # CC and LIBRARY_PATH: Always set for native compilation
    version = gcc_version
    if version
      system("/usr/libexec/PlistBuddy", "-c", "Add :LSEnvironment:CC string '#{HOMEBREW_PREFIX}/bin/gcc-#{version}'", plist)
    end

    library_path = build_library_path
    unless library_path.empty?
      system("/usr/libexec/PlistBuddy", "-c", "Add :LSEnvironment:LIBRARY_PATH string '#{library_path}'", plist)
    end

    # Touch the app to update LaunchServices cache
    system("touch", app)
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

  # Escape a string for embedding in an AppleScript double-quoted string
  # that will be passed to `do shell script` with single-quoted arguments.
  #
  # The escaping handles two layers:
  # 1. Shell: single quotes need '\'' idiom (end quote, escaped quote, start quote)
  # 2. AppleScript: backslashes and double quotes need escaping in double-quoted strings
  #
  # Example: PATH /usr/bin:/a'b becomes /usr/bin:/a'\\''b in the AppleScript source,
  # which AppleScript parses as /usr/bin:/a'\''b, which shell interprets correctly.
  #
  # Note: We use block form for gsub to avoid special meaning of \& and \' in
  # replacement strings (which would cause incorrect substitutions).
  def self.escape_for_applescript_shell(str)
    # First escape single quotes for shell: ' -> '\''
    shell_escaped = str.to_s.gsub("'") { "'\\''" }
    # Then escape backslashes and double quotes for AppleScript: \ -> \\, " -> \"
    shell_escaped.gsub('\\') { '\\\\' }.gsub('"') { '\\"' }
  end

  # Instance method wrapper for convenience
  def escape_for_applescript_shell(str)
    self.class.escape_for_applescript_shell(str)
  end

  def create_emacs_client_app(icons_dir)
    ohai "Creating Emacs Client.app"

    # Prepare PATH for injection into AppleScript (see escape_for_applescript_shell)
    # Use the same build_path logic as inject_path for consistency
    escaped_path = escape_for_applescript_shell(build_path)

    # Create AppleScript source
    client_script = buildpath/"emacs-client.applescript"
    client_script.write <<~EOS
      -- Emacs Client AppleScript Application
      -- Handles opening files from Finder, drag-and-drop, and launching from Spotlight/Dock

      on open theDropped
        repeat with oneDrop in theDropped
          set dropPath to quoted form of POSIX path of oneDrop
          try
            do shell script "PATH='#{escaped_path}' #{prefix}/bin/emacsclient -c -a '' -n " & dropPath
          end try
        end repeat
        try
          do shell script "open -a Emacs"
        end try
      end open

      -- Handle launch without files (from Spotlight, Dock, or Finder)
      on run
        try
          do shell script "PATH='#{escaped_path}' #{prefix}/bin/emacsclient -c -a '' -n"
        end try
        try
          do shell script "open -a Emacs"
        end try
      end run

      -- Handle org-protocol:// URLs (for org-capture, org-roam, etc.)
      on open location this_URL
        try
          do shell script "PATH='#{escaped_path}' #{prefix}/bin/emacsclient -n " & quoted form of this_URL
        end try
        try
          do shell script "open -a Emacs"
        end try
      end open location
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

    # Register org-protocol URL scheme for org-capture, org-roam, etc.
    system "/usr/libexec/PlistBuddy", "-c", "Add :CFBundleURLTypes array", client_plist
    system "/usr/libexec/PlistBuddy", "-c", "Add :CFBundleURLTypes:0 dict", client_plist
    system "/usr/libexec/PlistBuddy", "-c", "Add :CFBundleURLTypes:0:CFBundleURLName string 'Org Protocol'", client_plist
    system "/usr/libexec/PlistBuddy", "-c", "Add :CFBundleURLTypes:0:CFBundleURLSchemes array", client_plist
    system "/usr/libexec/PlistBuddy", "-c", "Add :CFBundleURLTypes:0:CFBundleURLSchemes:0 string org-protocol", client_plist

    # Install custom icon (replace osacompile's default droplet icon)
    client_resources_dir = buildpath/"nextstep/Emacs Client.app/Contents/Resources"

    # Use a simple filename without spaces to avoid quoting issues
    system "cp", icons_dir/"Emacs.icns", client_resources_dir/"applet.icns"

    # Remove default droplet resources created by osacompile
    system "rm", "-f", client_resources_dir/"droplet.icns"
    system "rm", "-f", client_resources_dir/"droplet.rsrc"

    # Handle Assets.car for macOS 26+ (Tahoe)
    # On Tahoe, the system prioritizes icon images from Assets.car over .icns files
    system "rm", "-f", client_resources_dir/"Assets.car"
    # If we have a custom Tahoe icon, copy it; otherwise the removal ensures .icns is used
    if File.exist?(icons_dir/"Assets.car")
      system "cp", icons_dir/"Assets.car", client_resources_dir/"Assets.car"
      # Set CFBundleIconName to match the icon name in Assets.car (defaults to "Emacs")
      icon = resolve_icon
      tahoe_icon_name = icon&.dig(:metadata, "tahoe_icon_name") || "Emacs"
      system "/usr/libexec/PlistBuddy -c 'Delete :CFBundleIconName' '#{client_plist}' 2>/dev/null || true"
      system "/usr/libexec/PlistBuddy", "-c", "Add :CFBundleIconName string #{tahoe_icon_name}", client_plist
    end

    # Set icon file reference (use simple name without spaces)
    # Try Delete first in case osacompile set it, then Add
    system "/usr/libexec/PlistBuddy -c 'Delete :CFBundleIconFile' '#{client_plist}' 2>/dev/null || true"
    system "/usr/libexec/PlistBuddy", "-c", "Add :CFBundleIconFile string applet", client_plist

    # Verify the icon was set correctly
    icon_check = `/usr/libexec/PlistBuddy -c 'Print :CFBundleIconFile' '#{client_plist}' 2>&1`.strip
    ohai "Emacs Client.app icon set to: #{icon_check}"
  end
end
