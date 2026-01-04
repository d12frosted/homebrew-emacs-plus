# frozen_string_literal: true

# CaskEnv - Environment setup for Emacs+ cask installations
#
# This module configures the Emacs.app bundle for proper operation when
# installed via cask. It handles:
#
# 1. LSEnvironment in Info.plist - Sets PATH, CC, LIBRARY_PATH so native
#    compilation works when launching from Finder/Dock
#
# 2. CLI wrapper script - Creates bin/emacs wrapper so running via symlink
#    from terminal can find bundle resources
#
# 3. Emacs Client.app - Recompiles AppleScript with proper PATH
#
# Configuration via ~/.config/emacs-plus/build.yml:
#   native_comp_env: true   # Enable (default)
#   native_comp_env: false  # Disable

require_relative 'BuildConfig'

module CaskEnv
  class << self
    # Inject environment into Emacs.app and Emacs Client.app
    # Returns true if any modifications were made
    def inject(emacs_app, emacs_client_app)
      # Check if injection is disabled in build.yml
      result = BuildConfig.load_config
      config = result[:config]

      if config.key?("native_comp_env") && !config["native_comp_env"]
        puts "Native compilation environment injection disabled in build.yml"
        return false
      end

      modified = false
      modified |= inject_emacs_app(emacs_app)
      modified |= inject_emacs_client_app(emacs_client_app)
      modified
    end

    private

    # Detect Homebrew prefix based on architecture
    def homebrew_prefix
      if Hardware::CPU.arm?
        "/opt/homebrew"
      else
        "/usr/local"
      end
    end

    # Build the PATH value for injection
    def build_path
      prefix = homebrew_prefix
      [
        "#{prefix}/bin",
        "#{prefix}/sbin",
        "/usr/bin",
        "/bin",
        "/usr/sbin",
        "/sbin",
      ].join(":")
    end

    # Find the gcc version number (e.g., "15")
    def gcc_version
      # Look for gcc-NN in Homebrew bin
      Dir.glob("#{homebrew_prefix}/bin/gcc-*").map do |path|
        File.basename(path).sub("gcc-", "")
      end.select { |v| v.match?(/^\d+$/) }.max
    end

    # Find the directory containing libemutls_w.a
    def find_emutls_dir
      gcc_cellar = "#{homebrew_prefix}/Cellar/gcc"
      return nil unless File.directory?(gcc_cellar)

      # Find libemutls_w.a in the gcc installation
      emutls_files = Dir.glob("#{gcc_cellar}/**/libemutls_w.a")
      return nil if emutls_files.empty?

      File.dirname(emutls_files.first)
    end

    # Build LIBRARY_PATH for native compilation
    def build_library_path
      prefix = homebrew_prefix
      paths = []

      # Add emutls directory (critical for native compilation)
      emutls_dir = find_emutls_dir
      paths << emutls_dir if emutls_dir

      # Add gcc library directories
      paths << "#{prefix}/lib/gcc/current"
      paths << "#{prefix}/lib"

      paths.compact.join(":")
    end

    # Inject environment into Emacs.app via LSEnvironment in Info.plist
    def inject_emacs_app(app_path)
      return false unless File.exist?(app_path)

      plist = "#{app_path}/Contents/Info.plist"

      # Check if already injected
      existing = `defaults read "#{plist}" LSEnvironment 2>/dev/null`.strip
      return false unless existing.empty? || existing.include?("does not exist")

      puts "Injecting native compilation environment into #{app_path}"

      prefix = homebrew_prefix
      version = gcc_version

      # Add LSEnvironment dict with PATH, CC, and LIBRARY_PATH
      system("/usr/libexec/PlistBuddy", "-c", "Add :LSEnvironment dict", plist)
      system("/usr/libexec/PlistBuddy", "-c", "Add :LSEnvironment:PATH string '#{build_path}'", plist)

      if version
        system("/usr/libexec/PlistBuddy", "-c", "Add :LSEnvironment:CC string '#{prefix}/bin/gcc-#{version}'", plist)
      end

      library_path = build_library_path
      unless library_path.empty?
        system("/usr/libexec/PlistBuddy", "-c", "Add :LSEnvironment:LIBRARY_PATH string '#{library_path}'", plist)
      end

      # Touch the app to update LaunchServices cache
      system("touch", app_path)

      # Create CLI wrapper script for terminal usage
      create_cli_wrapper(app_path)

      true
    end

    # Create a wrapper script at Emacs.app/Contents/MacOS/bin/emacs
    # This fixes the issue where running via symlink breaks Emacs's bundle path resolution
    def create_cli_wrapper(app_path)
      bin_dir = "#{app_path}/Contents/MacOS/bin"
      wrapper_path = "#{bin_dir}/emacs"

      # Skip if wrapper already exists
      return if File.exist?(wrapper_path) && File.read(wrapper_path).include?("emacs-plus wrapper")

      puts "Creating CLI wrapper script at #{wrapper_path}"

      # The wrapper uses the absolute path to the real binary
      File.write(wrapper_path, <<~SCRIPT)
        #!/bin/bash
        # emacs-plus wrapper script for CLI usage
        # This ensures Emacs can find its bundle resources when invoked via symlink
        exec "#{app_path}/Contents/MacOS/Emacs" "$@"
      SCRIPT

      File.chmod(0755, wrapper_path)
    end

    # Inject PATH into Emacs Client.app by recompiling the AppleScript
    def inject_emacs_client_app(app_path)
      return false unless File.exist?(app_path)

      # Check if we need to recompile (look for our marker in Info.plist)
      plist = "#{app_path}/Contents/Info.plist"
      marker_check = `defaults read "#{plist}" EmacsPlusPathInjected 2>/dev/null`.strip
      return false if marker_check == "1"

      puts "Injecting PATH into #{app_path}"

      # The emacsclient path - use the symlinked binary from Homebrew prefix
      emacsclient = "#{homebrew_prefix}/bin/emacsclient"

      # Build escaped PATH for AppleScript
      escaped_path = escape_for_applescript_shell(build_path)

      # Create temporary AppleScript source
      script_content = <<~APPLESCRIPT
        -- Emacs Client AppleScript Application
        -- Handles opening files from Finder, drag-and-drop, and launching from Spotlight/Dock

        on open theDropped
          repeat with oneDrop in theDropped
            set dropPath to quoted form of POSIX path of oneDrop
            try
              do shell script "PATH='#{escaped_path}' #{emacsclient} -c -a '' -n " & dropPath
            end try
          end repeat
          try
            do shell script "open -a Emacs"
          end try
        end open

        -- Handle launch without files (from Spotlight, Dock, or Finder)
        on run
          try
            do shell script "PATH='#{escaped_path}' #{emacsclient} -c -a '' -n"
          end try
          try
            do shell script "open -a Emacs"
          end try
        end run

        -- Handle org-protocol:// URLs (for org-capture, org-roam, etc.)
        on open location this_URL
          try
            do shell script "PATH='#{escaped_path}' #{emacsclient} -n " & quoted form of this_URL
          end try
          try
            do shell script "open -a Emacs"
          end try
        end open location
      APPLESCRIPT

      # Write and compile the script
      require 'tempfile'
      Tempfile.create(['emacs-client', '.applescript']) do |f|
        f.write(script_content)
        f.flush

        # Save current icon and resources before recompiling
        resources_dir = "#{app_path}/Contents/Resources"
        icon_backup = nil
        assets_backup = nil

        if File.exist?("#{resources_dir}/applet.icns")
          icon_backup = File.read("#{resources_dir}/applet.icns", mode: 'rb')
        end
        if File.exist?("#{resources_dir}/Assets.car")
          assets_backup = File.read("#{resources_dir}/Assets.car", mode: 'rb')
        end

        # Recompile the AppleScript
        system("osacompile", "-o", app_path, f.path)

        # Restore icon
        if icon_backup
          File.write("#{resources_dir}/applet.icns", icon_backup, mode: 'wb')
          # Remove default droplet resources
          FileUtils.rm_f("#{resources_dir}/droplet.icns")
          FileUtils.rm_f("#{resources_dir}/droplet.rsrc")
        end
        if assets_backup
          File.write("#{resources_dir}/Assets.car", assets_backup, mode: 'wb')
        end
      end

      # Mark as injected
      system("defaults", "write", plist, "EmacsPlusPathInjected", "-bool", "true")

      # Restore plist settings that osacompile might have overwritten
      system("/usr/libexec/PlistBuddy", "-c", "Set :CFBundleIdentifier org.gnu.EmacsClient", plist)
      system("/usr/libexec/PlistBuddy", "-c", "Set :CFBundleName 'Emacs Client'", plist)
      system("/usr/libexec/PlistBuddy", "-c", "Set :CFBundleIconFile applet", plist)

      true
    end

    # Escape a string for embedding in an AppleScript double-quoted string
    # that will be passed to `do shell script` with single-quoted arguments.
    def escape_for_applescript_shell(str)
      # First escape single quotes for shell: ' -> '\''
      shell_escaped = str.to_s.gsub("'") { "'\\''" }
      # Then escape backslashes and double quotes for AppleScript: \ -> \\, " -> \"
      shell_escaped.gsub('\\') { '\\\\' }.gsub('"') { '\\"' }
    end
  end
end
