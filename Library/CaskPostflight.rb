# frozen_string_literal: true

# CaskPostflight - Shared postflight logic for emacs-plus-app casks
#
# All emacs-plus-app* casks run the same post-install steps; only the
# release channel they download differs. This module keeps that logic in
# one place so the casks cannot drift apart. It handles:
#
# 1. Removing the quarantine attribute from both app bundles
# 2. Environment injection (CaskEnv) and custom icon (IconApplier)
# 3. Re-signing the bundles if they were modified
#
# The bin/emacs symlink is a `symlink` step in the cask's postflight_steps
# (it runs after this module has generated the wrapper), so Homebrew
# creates and removes it without any help from here.
#
# ctx provides system_command(cmd, args:, sudo:); the casks run this module
# through scripts/cask-postflight, which supplies a shell-backed one.

require 'fileutils'
require_relative 'CaskEnv'
require_relative 'IconApplier'

module CaskPostflight
  class << self
    def run(ctx, emacs_app:, emacs_client_app:, version:)
      remove_quarantine(ctx, emacs_app)
      remove_quarantine(ctx, emacs_client_app)

      # Environment setup for native compilation and CLI usage
      needs_resign = CaskEnv.inject(emacs_app, emacs_client_app)

      # Apply custom icon from ~/.config/emacs-plus/build.yml if configured
      needs_resign = IconApplier.apply(emacs_app, emacs_client_app, version: version) || needs_resign

      return unless needs_resign

      resign(ctx, emacs_app)
      resign(ctx, emacs_client_app)
    end

    private

    def remove_quarantine(ctx, app)
      ctx.system_command "/usr/bin/xattr",
                         args: ["-r", "-d", "com.apple.quarantine", app],
                         sudo: false
    end

    def resign(ctx, app)
      ctx.system_command "/usr/bin/codesign",
                         args: ["--force", "--deep", "--sign", "-", app],
                         sudo: false
    end
  end
end
