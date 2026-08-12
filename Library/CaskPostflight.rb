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
# 4. Symlinking bin/emacs into HOMEBREW_PREFIX
#
# The matching cleanup (removing the emacs symlink) stays inline in each
# cask's uninstall_postflight so uninstall does not depend on this file.
#
# ctx is the cask's postflight block (self), which provides system_command.

require 'fileutils'
require_relative 'CaskEnv'
require_relative 'IconApplier'

module CaskPostflight
  class << self
    def run(ctx, emacs_app:, emacs_client_app:, version:, homebrew_prefix:)
      remove_quarantine(ctx, emacs_app)
      remove_quarantine(ctx, emacs_client_app)

      # Environment setup for native compilation and CLI usage
      needs_resign = CaskEnv.inject(emacs_app, emacs_client_app)

      # Apply custom icon from ~/.config/emacs-plus/build.yml if configured
      needs_resign = IconApplier.apply(emacs_app, emacs_client_app, version: version) || needs_resign

      if needs_resign
        resign(ctx, emacs_app)
        resign(ctx, emacs_client_app)
      end

      link_emacs(emacs_app, homebrew_prefix)
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

    # Create the emacs symlink manually: the wrapper script is generated
    # by CaskEnv during postflight, and binary stanzas run before that.
    def link_emacs(emacs_app, homebrew_prefix)
      emacs_wrapper = "#{emacs_app}/Contents/MacOS/bin/emacs"
      emacs_symlink = "#{homebrew_prefix}/bin/emacs"
      if File.exist?(emacs_wrapper) && !File.exist?(emacs_symlink)
        FileUtils.ln_sf(emacs_wrapper, emacs_symlink)
      end
    end
  end
end
