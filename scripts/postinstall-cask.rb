#!/usr/bin/env ruby
# frozen_string_literal: true

# Simulate cask postflight scripts on an existing Emacs.app installation.
# This allows testing icon application and environment injection without reinstalling.
#
# Usage: ruby scripts/postinstall-cask.rb [/path/to/Emacs.app]

$LOAD_PATH.unshift File.expand_path('../Library', __dir__)

require 'BuildConfig'
require 'CaskEnv'
require 'IconApplier'

# Find Emacs.app
def find_emacs_app(arg)
  candidates = [
    arg,
    '/Applications/Emacs.app',
    '/opt/homebrew/opt/emacs-plus@31/Emacs.app',
    '/opt/homebrew/opt/emacs-plus@30/Emacs.app',
    "#{ENV['HOME']}/Applications/Emacs.app",
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
  puts "Usage: ruby scripts/postinstall-cask.rb [/path/to/Emacs.app]"
  puts ""
  puts "Searched locations:"
  puts "  - /Applications/Emacs.app"
  puts "  - /opt/homebrew/opt/emacs-plus@{30,31}/Emacs.app"
  puts "  - ~/Applications/Emacs.app"
  exit 1
end

emacs_client_app = find_emacs_client_app(emacs_app)

puts "==> Found Emacs.app: #{emacs_app}"
puts "==> Found Emacs Client.app: #{emacs_client_app || '(not found)'}"
puts

# Run CaskEnv.inject (environment setup)
puts "==> Running CaskEnv.inject..."
begin
  modified = CaskEnv.inject(emacs_app, emacs_client_app)
  puts modified ? "    Environment injected" : "    No changes needed"
rescue BuildConfig::ConfigurationError => e
  puts "Error: #{e.message}"
  exit 1
end
puts

# Run IconApplier.apply (custom icon)
puts "==> Running IconApplier.apply..."
begin
  applied = IconApplier.apply(emacs_app, emacs_client_app)
  puts applied ? "    Icon applied" : "    No custom icon configured"
rescue BuildConfig::ConfigurationError => e
  puts "Error: #{e.message}"
  exit 1
end
puts

puts "==> Postflight simulation complete"
