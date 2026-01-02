# frozen_string_literal: true

# Shared module for parsing build.yml and resolving icons/patches from the community registry.
# Used by both the formula (EmacsBase) and cask (postflight).

require 'yaml'
require 'json'
require 'etc'

module BuildConfig
  class << self
    def tap_path
      @tap_path ||= File.expand_path('..', __dir__)
    end

    # Load build configuration from ~/.config/emacs-plus/build.yml
    def load_config
      config_source = nil
      config = {}

      # Get real home directory (Homebrew sandboxes HOME to a temp dir)
      real_home = Etc.getpwuid.dir

      if ENV["HOMEBREW_EMACS_PLUS_BUILD_CONFIG"]
        path = File.expand_path(ENV["HOMEBREW_EMACS_PLUS_BUILD_CONFIG"])
        if File.exist?(path)
          config = YAML.load_file(path)
          config_source = path
        end
      else
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

      { config: config || {}, source: config_source }
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
