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
      case icon
      when String, nil
        # Valid: icon name from registry or no icon
        return
      when Hash
        unless icon["url"] && icon["sha256"]
          raise ConfigurationError,
            "Invalid 'icon' configuration in #{path}\n" \
            "When specifying an external icon, both 'url' and 'sha256' are required.\n" \
            "Got: #{icon.inspect}"
        end
      else
        raise ConfigurationError,
          "Invalid 'icon' in #{path}\n" \
          "Expected: string (icon name) or object with 'url' and 'sha256'\n" \
          "Got: #{icon.inspect} (#{icon.class})"
      end
    end

    def validate_inject_path!(value, path)
      return if [true, false].include?(value)

      raise ConfigurationError,
        "Invalid 'inject_path' in #{path}\n" \
        "Expected: true or false\n" \
        "Got: #{value.inspect} (#{value.class})"
    end

    def validate_patches!(patches, path)
      return if patches.is_a?(Array)

      raise ConfigurationError,
        "Invalid 'patches' in #{path}\n" \
        "Expected: array of patch names\n" \
        "Got: #{patches.inspect} (#{patches.class})\n\n" \
        "Example:\n" \
        "  patches:\n" \
        "    - frame-transparency\n" \
        "    - aggressive-read-buffering"
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
        formatted_value = case value
        when Hash then value.map { |k, v| "#{k}: #{v}" }.join(", ")
        when Array then value.join(", ")
        else value.to_s
        end
        output.call "  #{key}: #{formatted_value}"
      end

      # Context-specific warnings
      warnings = context_warnings(config, context)
      warnings.each { |w| output.call "  ⚠ #{w}" }
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
    # Returns nil if no icon configured
    # Returns hash with :name, :path, :tahoe_path, :type, :metadata, or :url/:sha256 for external
    def resolve_icon(config)
      return nil unless config["icon"]

      icon_ref = config["icon"]
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
