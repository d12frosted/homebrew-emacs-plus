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
    '/opt/homebrew/opt/emacs-plus@31/Emacs.app',
    '/opt/homebrew/opt/emacs-plus@30/Emacs.app',
    '/opt/homebrew/opt/emacs-plus@29/Emacs.app',
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

emacs_app = find_emacs_app(ARGV[0])

unless emacs_app
  puts "Error: Could not find Emacs.app"
  puts "Usage: ruby scripts/postinstall-formula.rb [/path/to/Emacs.app]"
  puts ""
  puts "Searched locations:"
  puts "  - /opt/homebrew/opt/emacs-plus@{29,30,31}/Emacs.app"
  puts "  - /usr/local/opt/emacs-plus@{30,31}/Emacs.app"
  exit 1
end

emacs_client_app = find_emacs_client_app(emacs_app)

puts "==> Found Emacs.app: #{emacs_app}"
puts "==> Found Emacs Client.app: #{emacs_client_app || '(not found)'}"
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
if config["icon"].is_a?(String)
  registry = BuildConfig.registry
  unless registry.dig("icons", config["icon"])
    puts "Error: Unknown icon '#{config["icon"]}'"
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
  applied = IconApplier.apply(emacs_app, emacs_client_app)
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
