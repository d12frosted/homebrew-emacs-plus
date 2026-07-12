#!/usr/bin/env ruby
# frozen_string_literal: true

# Simulate formula post_install scripts on an existing Emacs.app installation.
# This allows testing icon application without rebuilding.
#
# Note: Some post_install operations (PATH injection, site-lisp setup) require
# Homebrew context and can't be fully simulated. This script focuses on:
# - Config validation
# - Icon application
#
# Usage: ruby scripts/postinstall-formula.rb [/path/to/Emacs.app]

$LOAD_PATH.unshift File.expand_path('../Library', __dir__)

require 'BuildConfig'
require 'IconApplier'

# Find Emacs.app
def find_emacs_app(arg)
  candidates = [
    arg,
    '/opt/homebrew/opt/emacs-plus@32/Emacs.app',
    '/opt/homebrew/opt/emacs-plus@31/Emacs.app',
    '/opt/homebrew/opt/emacs-plus@30/Emacs.app',
    '/opt/homebrew/opt/emacs-plus@29/Emacs.app',
    '/usr/local/opt/emacs-plus@32/Emacs.app',
    '/usr/local/opt/emacs-plus@31/Emacs.app',
    '/usr/local/opt/emacs-plus@30/Emacs.app',
  ].compact

  candidates.find { |path| File.exist?(path) }
end

def find_emacs_client_app(emacs_app)
  dir = File.dirname(emacs_app)
  client = File.join(dir, 'Emacs Client.app')
  File.exist?(client) ? client : nil
end

# Major Emacs version for version-mapped config, from the formula path
# (emacs-plus@NN) or the app bundle's Info.plist
def detect_major_version(emacs_app)
  return Regexp.last_match(1) if emacs_app =~ /emacs-plus@(\d+)/

  plist = File.join(emacs_app, 'Contents', 'Info.plist')
  ver = `/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' '#{plist}' 2>/dev/null`.strip
  ver[/\A\d+/]
end

emacs_app = find_emacs_app(ARGV[0])

unless emacs_app
  puts "Error: Could not find Emacs.app"
  puts "Usage: ruby scripts/postinstall-formula.rb [/path/to/Emacs.app]"
  puts ""
  puts "Searched locations:"
  puts "  - /opt/homebrew/opt/emacs-plus@{29,30,31,32}/Emacs.app"
  puts "  - /usr/local/opt/emacs-plus@{30,31,32}/Emacs.app"
  exit 1
end

emacs_client_app = find_emacs_client_app(emacs_app)
major_version = detect_major_version(emacs_app)

puts "==> Found Emacs.app: #{emacs_app}"
puts "==> Found Emacs Client.app: #{emacs_client_app || '(not found)'}"
puts "==> Emacs major version: #{major_version || '(unknown)'}"
puts

# Load and validate config
puts "==> Loading build config..."
begin
  result = BuildConfig.load_config
  config = result[:config]

  if result[:source]
    puts "    Loaded from: #{result[:source]}"
    BuildConfig.print_config(config, result[:source], context: :formula, output: ->(msg) { puts "    #{msg}" })
  else
    puts "    No build config found"
  end
rescue BuildConfig::ConfigurationError => e
  puts "Error: #{e.message}"
  exit 1
end
puts

# Validate against registry (formula-specific validation)
icon_names = if BuildConfig.version_map?(config["icon"])
  config["icon"].values.grep(String)
elsif config["icon"].is_a?(String)
  [config["icon"]]
else
  []
end
icon_names.each do |name|
  registry = BuildConfig.registry
  unless registry.dig("icons", name)
    puts "Error: Unknown icon '#{name}'"
    puts "Check community/registry.json for available icons."
    exit 1
  end
end

if config["patches"].is_a?(Array)
  registry = BuildConfig.registry
  config["patches"].each do |patch|
    next unless patch.is_a?(String)
    unless registry.dig("patches", patch)
      puts "Error: Unknown patch '#{patch}'"
      puts "Check community/registry.json for available patches."
      exit 1
    end
  end
end

puts "==> Config validated successfully"
puts

# Apply icon
puts "==> Running IconApplier.apply..."
begin
  applied = IconApplier.apply(emacs_app, emacs_client_app, version: major_version)
  puts applied ? "    Icon applied" : "    No custom icon configured"
rescue => e
  puts "Error: #{e.message}"
  exit 1
end
puts

puts "==> Post-install simulation complete"
puts ""
puts "Note: PATH injection and site-lisp setup require full Homebrew context"
puts "and are not simulated here. Run 'brew postinstall emacs-plus@XX' for those."
