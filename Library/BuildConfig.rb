# frozen_string_literal: true

# Shared module for parsing build.yml and resolving icons/patches from the community registry.
# Used by both the formula (EmacsBase) and cask (postflight).

require 'yaml'
require 'json'
require 'etc'

module BuildConfig
  # Custom error for configuration problems with helpful messages
  class ConfigurationError < StandardError; end

  # Known configuration keys by context
  FORMULA_KEYS = %w[icon patches revision inject_path].freeze
  CASK_KEYS = %w[icon inject_path].freeze
  ALL_KEYS = (FORMULA_KEYS + CASK_KEYS).uniq.freeze

  # Keys of an external resource spec ({url, sha256}). A hash whose keys are
  # a subset of these is a spec; any other hash is a version map keyed by
  # major Emacs version (or "default"). A version key is never literally
  # "url" or "sha256", so the two shapes cannot collide.
  SPEC_KEYS = %w[url sha256].freeze

  # Valid version map key: "default" or a major Emacs version like "30"/30
  VERSION_KEY = /\A\d+\z/

  class << self
    def tap_path
      @tap_path ||= File.expand_path('..', __dir__)
    end

    # Load build configuration from ~/.config/emacs-plus/build.yml
    # Raises ConfigurationError with helpful message for malformed configs
    def load_config
      config_source = nil
      config = {}

      # Get real home directory (Homebrew sandboxes HOME to a temp dir)
      real_home = Etc.getpwuid.dir

      if ENV["HOMEBREW_EMACS_PLUS_BUILD_CONFIG"]
        path = File.expand_path(ENV["HOMEBREW_EMACS_PLUS_BUILD_CONFIG"])
        if File.exist?(path)
          config = load_and_validate_yaml(path)
          config_source = path
        end
      else
        paths = [
          "#{real_home}/.config/emacs-plus/build.yml",
          "#{real_home}/.emacs-plus-build.yml"
        ]
        config_file = paths.find { |p| File.exist?(p) }
        if config_file
          config = load_and_validate_yaml(config_file)
          config_source = config_file
        end
      end

      { config: config || {}, source: config_source }
    end

    # Load YAML file and validate its structure
    # Returns empty hash for empty files, raises ConfigurationError for invalid configs
    def load_and_validate_yaml(path)
      content = File.read(path)
      return {} if content.strip.empty?

      begin
        config = YAML.safe_load(content, permitted_classes: [Symbol])
      rescue Psych::SyntaxError => e
        raise ConfigurationError,
          "YAML syntax error in #{path}\n" \
          "#{e.message}\n\n" \
          "Tip: Validate your YAML at https://yamlchecker.com/"
      end

      validate_config!(config, path)
      config
    end

    # True if value is an external resource spec: {url, sha256}
    def external_spec?(value)
      value.is_a?(Hash) && !value.empty? && (value.keys.map(&:to_s) - SPEC_KEYS).empty?
    end

    # True if value is a version map: a hash keyed by major version/"default"
    def version_map?(value)
      value.is_a?(Hash) && !external_spec?(value)
    end

    # Resolve a possibly version-mapped value for a major Emacs version.
    # Plain values (string, spec hash, nil) pass through unchanged.
    # For a version map: exact version match wins, then "default", else nil.
    # Handles both string and integer keys/versions ("30" vs 30).
    def resolve_versioned(value, version)
      return value unless version_map?(value)

      version = version&.to_s
      exact = value.keys.find { |k| k.to_s == version }
      return value[exact] if exact

      default = value.keys.find { |k| k.to_s == "default" }
      default ? value[default] : nil
    end

    # Elisp block for site-start.el that lets the libgccjit driver link
    # .eln files no matter how Emacs was launched (issue #964).
    #
    # LIBRARY_PATH injected via LSEnvironment reaches GUI launches only, so
    # a terminal-launched Emacs with a cold eln-cache fails at the link step
    # ("ld: library 'emutls_w' not found"). Driver options are passed only
    # to libgccjit, so unlike setenv they do not leak into child processes
    # of Emacs (issue #939). The gcc paths are resolved at Emacs startup, so
    # they survive gcc version bumps without a reinstall.
    def native_comp_driver_options_el(prefix)
      <<~ELISP
        ;; Native compilation: pass gcc library dirs to the libgccjit driver
        ;; so it can link .eln files (ld needs libemutls_w.a and friends).
        ;; LIBRARY_PATH from LSEnvironment covers GUI launches only, so a
        ;; terminal-launched Emacs with a cold eln-cache fails to link
        ;; without this. Driver options reach only libgccjit, so unlike
        ;; setenv they do not leak into child processes of Emacs.
        (when (and (fboundp 'native-comp-available-p)
                   (native-comp-available-p))
          (let* ((gcc (car (last (sort (file-expand-wildcards
                                        "#{prefix}/opt/gcc/bin/gcc-[0-9]*")
                                       #'string-version-lessp))))
                 (emutls (when gcc
                           (with-temp-buffer
                             (when (eql 0 (ignore-errors
                                            (call-process
                                             gcc nil t nil
                                             "-print-file-name=libemutls_w.a")))
                               (string-trim (buffer-string))))))
                 (dirs (list (when (and emutls (string-match-p "/" emutls))
                               (directory-file-name
                                (expand-file-name (file-name-directory emutls))))
                             "#{prefix}/lib/gcc/current"
                             "#{prefix}/opt/libgccjit/lib/gcc/current"
                             "#{prefix}/lib")))
            (unless (boundp 'native-comp-driver-options)
              (setq native-comp-driver-options nil))
            (dolist (dir dirs)
              (when dir
                (let ((flag (concat "-L" dir)))
                  (unless (member flag native-comp-driver-options)
                    (setq native-comp-driver-options
                          (append native-comp-driver-options (list flag)))))))))
      ELISP
    end

    # Validate that config has the expected structure
    def validate_config!(config, path)
      unless config.is_a?(Hash)
        raise ConfigurationError,
          "Invalid build.yml at #{path}\n" \
          "Expected a YAML mapping (key: value pairs), but got: #{config.class}\n" \
          "Content: #{config.inspect[0..100]}\n\n" \
          "Common causes:\n" \
          "  - Missing space after colon (use 'icon: value' not 'icon:value')\n" \
          "  - File contains only a string instead of key-value pairs"
      end

      # Check for unknown keys
      unknown_keys = config.keys - ALL_KEYS
      unless unknown_keys.empty?
        suggestions = unknown_keys.map { |k| suggest_key(k) }.compact
        suggestion_text = suggestions.empty? ? "" : "\n\nDid you mean:\n#{suggestions.map { |s| "  - #{s}" }.join("\n")}"

        raise ConfigurationError,
          "Unknown configuration key(s) in #{path}: #{unknown_keys.join(', ')}\n" \
          "Valid keys are: #{ALL_KEYS.join(', ')}#{suggestion_text}"
      end

      # Validate individual keys
      validate_icon!(config["icon"], path) if config.key?("icon")
      validate_patches!(config["patches"], path) if config.key?("patches")
      validate_revision!(config["revision"], path) if config.key?("revision")
      validate_inject_path!(config["inject_path"], path) if config.key?("inject_path")
    end

    # Suggest correct key name for typos
    def suggest_key(unknown_key)
      ALL_KEYS.find do |valid_key|
        # Simple similarity: same first letter or Levenshtein distance <= 2
        unknown_key[0]&.downcase == valid_key[0] ||
          levenshtein_distance(unknown_key.downcase, valid_key) <= 2
      end&.then { |key| "'#{unknown_key}' -> '#{key}'" }
    end

    # Simple Levenshtein distance for typo detection
    def levenshtein_distance(s1, s2)
      m, n = s1.length, s2.length
      return n if m.zero?
      return m if n.zero?

      d = Array.new(m + 1) { |i| i }
      (1..n).each do |j|
        prev = d[0]
        d[0] = j
        (1..m).each do |i|
          temp = d[i]
          d[i] = [d[i] + 1, d[i - 1] + 1, prev + (s1[i - 1] == s2[j - 1] ? 0 : 1)].min
          prev = temp
        end
      end
      d[m]
    end

    def validate_icon!(icon, path)
      # An empty hash is neither a usable spec nor a version map; let the
      # spec validator produce the "url and sha256 required" error for it
      if version_map?(icon) && !icon.empty?
        validate_version_map_keys!(icon, "icon", path)
        icon.each do |ver, spec|
          if version_map?(spec)
            raise ConfigurationError,
              "Invalid 'icon.#{ver}' in #{path}\n" \
              "Version maps cannot be nested.\n" \
              "Got: #{spec.inspect}"
          end
          validate_icon_spec!(spec, path, key: "icon.#{ver}")
        end
      else
        validate_icon_spec!(icon, path)
      end
    end

    def validate_icon_spec!(icon, path, key: "icon")
      case icon
      when String, nil
        # Valid: icon name from registry or no icon
        return
      when Hash
        unless icon["url"] && icon["sha256"]
          raise ConfigurationError,
            "Invalid '#{key}' configuration in #{path}\n" \
            "When specifying an external icon, both 'url' and 'sha256' are required.\n" \
            "Got: #{icon.inspect}"
        end
      else
        raise ConfigurationError,
          "Invalid '#{key}' in #{path}\n" \
          "Expected: string (icon name) or object with 'url' and 'sha256'\n" \
          "Got: #{icon.inspect} (#{icon.class})"
      end
    end

    # Validate that all keys of a version map are major versions or "default"
    def validate_version_map_keys!(map, key, path)
      bad = map.keys.reject { |k| k.to_s == "default" || k.to_s.match?(VERSION_KEY) }
      return if bad.empty?

      raise ConfigurationError,
        "Invalid '#{key}' version map in #{path}\n" \
        "Version keys must be major Emacs versions (e.g. \"30\") or 'default'.\n" \
        "Got key(s): #{bad.map(&:inspect).join(', ')}"
    end

    def validate_inject_path!(value, path)
      return if [true, false].include?(value)

      raise ConfigurationError,
        "Invalid 'inject_path' in #{path}\n" \
        "Expected: true or false\n" \
        "Got: #{value.inspect} (#{value.class})"
    end

    def validate_patches!(patches, path)
      unless patches.is_a?(Array)
        raise ConfigurationError,
          "Invalid 'patches' in #{path}\n" \
          "Expected: array of patch names\n" \
          "Got: #{patches.inspect} (#{patches.class})\n\n" \
          "Example:\n" \
          "  patches:\n" \
          "    - frame-transparency\n" \
          "    - aggressive-read-buffering"
      end

      patches.each do |entry|
        case entry
        when String
          # Valid: patch name from registry
        when Hash
          entry.each do |name, value|
            if version_map?(value) && !value.empty?
              validate_version_map_keys!(value, "patches.#{name}", path)
              value.each do |ver, spec|
                validate_patch_spec!(spec, path, key: "patches.#{name}.#{ver}")
              end
            else
              validate_patch_spec!(value, path, key: "patches.#{name}")
            end
          end
        else
          raise ConfigurationError,
            "Invalid 'patches' entry in #{path}\n" \
            "Expected: patch name (string) or named patch with 'url' and 'sha256'\n" \
            "Got: #{entry.inspect} (#{entry.class})"
        end
      end
    end

    def validate_patch_spec!(spec, path, key:)
      return if spec.is_a?(Hash) && spec["url"] && spec["sha256"]

      raise ConfigurationError,
        "Invalid '#{key}' in #{path}\n" \
        "External and local patches require both 'url' and 'sha256'.\n" \
        "Got: #{spec.inspect}"
    end

    def validate_revision!(revision, path)
      case revision
      when String
        unless revision.match?(/\A[a-f0-9]+\z/i)
          raise ConfigurationError,
            "Invalid 'revision' in #{path}\n" \
            "Expected: git commit hash (hex string)\n" \
            "Got: #{revision.inspect}"
        end
      when Hash
        validate_version_map_keys!(revision, "revision", path)
        revision.each do |ver, rev|
          unless rev.is_a?(String) && rev.match?(/\A[a-f0-9]+\z/i)
            raise ConfigurationError,
              "Invalid 'revision.#{ver}' in #{path}\n" \
              "Expected: git commit hash (hex string)\n" \
              "Got: #{rev.inspect}"
          end
        end
      else
        raise ConfigurationError,
          "Invalid 'revision' in #{path}\n" \
          "Expected: git commit hash or version-specific hash map\n" \
          "Got: #{revision.inspect} (#{revision.class})\n\n" \
          "Examples:\n" \
          "  revision: abc123def456\n" \
          "or:\n" \
          "  revision:\n" \
          "    \"30\": abc123\n" \
          "    \"31\": def456"
      end
    end

    # Print config contents for verbose output
    # @param config [Hash] The configuration hash
    # @param source [String] Path to the config file
    # @param context [Symbol] :formula or :cask
    # @param output [Proc] Output method (e.g., method(:puts) or Homebrew's ohai)
    def print_config(config, source, context: :formula, output: method(:puts))
      return if config.empty?

      output.call "Build configuration:"
      config.each do |key, value|
        output.call "  #{key}: #{format_config_value(value)}"
      end

      # Context-specific warnings
      warnings = context_warnings(config, context)
      warnings.each { |w| output.call "  ⚠ #{w}" }
    end

    # Format a config value for display, flattening nested hashes
    # (external specs and version maps) into a compact one-line form
    def format_config_value(value)
      case value
      when Hash then value.map { |k, v| "#{k}: #{format_config_value(v)}" }.join(", ")
      when Array then value.map { |v| format_config_value(v) }.join(", ")
      else value.to_s
      end
    end

    # Get warnings for keys that don't apply to the current context
    # @param config [Hash] The configuration hash
    # @param context [Symbol] :formula or :cask
    # @return [Array<String>] Warning messages
    def context_warnings(config, context)
      warnings = []
      case context
      when :cask
        warnings << "'patches' is ignored (patches are only applied during formula builds)" if config.key?("patches")
        warnings << "'revision' is ignored (revision pinning is only used during formula builds)" if config.key?("revision")
      end
      warnings
    end

    # Load the community registry
    def registry
      @registry ||= begin
        registry_file = "#{tap_path}/community/registry.json"
        File.exist?(registry_file) ? JSON.parse(File.read(registry_file)) : { "patches" => {}, "icons" => {} }
      end
    end

    # Resolve an icon from build.yml configuration
    # Supports a plain spec (name or {url, sha256}) or a version map
    # ({default: spec, "30": spec, ...}); version is the major Emacs version.
    # Returns nil if no icon configured (or none for this version)
    # Returns hash with :name, :path, :tahoe_path, :type, :metadata, or :url/:sha256 for external
    def resolve_icon(config, version: nil)
      icon_ref = resolve_versioned(config["icon"], version)
      return nil unless icon_ref

      case icon_ref
      when String
        resolve_registry_icon(icon_ref)
      when Hash
        return nil unless icon_ref["url"] && icon_ref["sha256"]
        { url: icon_ref["url"], sha256: icon_ref["sha256"], type: "external" }
      else
        nil
      end
    end

    # Format maintainer for display
    def format_maintainer(maintainer)
      return nil unless maintainer
      if maintainer.is_a?(String)
        "@#{maintainer}"
      elsif maintainer["github"]
        "@#{maintainer["github"]}"
      elsif maintainer["name"]
        maintainer["name"]
      end
    end

    private

    def resolve_registry_icon(name)
      info = registry.dig("icons", name)
      return nil unless info

      icon_dir = "#{tap_path}/community/#{info['directory']}"
      icon_file = "#{icon_dir}/icon.icns"
      return nil unless File.exist?(icon_file)

      metadata_file = "#{icon_dir}/metadata.json"
      metadata = File.exist?(metadata_file) ? JSON.parse(File.read(metadata_file)) : {}

      # Check for Tahoe Assets.car (macOS 26+)
      assets_car = "#{icon_dir}/Assets.car"
      tahoe_path = File.exist?(assets_car) ? assets_car : nil

      { name: name, path: icon_file, tahoe_path: tahoe_path, type: "community", metadata: metadata }
    end
  end
end
