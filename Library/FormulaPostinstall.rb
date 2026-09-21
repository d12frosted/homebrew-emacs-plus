# frozen_string_literal: true

# FormulaPostinstall - Shared post-install logic for the emacs-plus formulas
#
# Every emacs-plus@N formula used to carry a `post_install` method with the
# same handful of steps. Homebrew 7 deprecated that method in favour of
# `post_install_steps`, a fixed list of literal steps, so the Ruby lives here
# and the formulas run it through scripts/formula-postinstall as a `run`
# step. It handles:
#
# 1. Registering the Emacs info manuals in share/info/emacs/dir
# 2. The Emacs.app/Contents/native-lisp link (Emacs 28 and 29 with native-comp)
# 3. Re-applying the custom icon from build.yml (Emacs 30 and later)
# 4. Re-signing Emacs.app and Emacs Client.app (issue #742)
#
# Which of 1-3 run is up to the formula: older formulas never re-applied
# icons after install and newer ones have no native-lisp link, so the flags
# keep each formula doing exactly what its post_install did. Re-signing
# always runs for the bundles that exist.
#
# ctx provides system_command(cmd, args:); the formulas run this module
# through scripts/formula-postinstall, which supplies a shell-backed one that
# raises CommandError on failure, the way Formula#system used to.

require 'fileutils'
require_relative 'IconApplier'

module FormulaPostinstall
  class CommandError < StandardError; end

  class << self
    def run(ctx, prefix:, version: nil, opt_prefix: nil,
            install_info: false, apply_icon: false, link_native_lisp: false)
      prefix = prefix.to_s
      emacs_app = File.join(prefix, 'Emacs.app')
      client_app = File.join(prefix, 'Emacs Client.app')

      register_info_files(ctx, File.join(prefix, 'share/info/emacs')) if install_info
      link_native_lisp(opt_prefix.to_s) if link_native_lisp
      IconApplier.apply(emacs_app, client_app, version: version) if apply_icon

      resign(ctx, emacs_app, 'Emacs.app') if File.exist?(emacs_app)
      resign(ctx, client_app, 'Emacs Client.app') if File.exist?(client_app)
    end

    private

    def register_info_files(ctx, info_dir)
      return unless File.directory?(info_dir)

      Dir.glob(File.join(info_dir, '*.info{,.gz}')).sort.each do |info_file|
        ctx.system_command 'install-info', args: ["--info-dir=#{info_dir}", info_file]
      end
    end

    # Emacs 28 and 29 keep the eln cache under lib/emacs/<version>/native-lisp
    # and link it into the app bundle through the opt prefix, so the link
    # keeps pointing at the current version across upgrades. The directory
    # only exists for native-comp builds; without it there is nothing to link.
    def link_native_lisp(opt_prefix)
      emacs_lib = Dir[File.join(opt_prefix, 'lib/emacs/*')].first
      return unless emacs_lib

      native_lisp = File.join(emacs_lib, 'native-lisp')
      return unless File.directory?(native_lisp)

      FileUtils.ln_sf native_lisp, File.join(opt_prefix, 'Emacs.app/Contents/native-lisp')
    end

    def resign(ctx, app, label)
      puts "==> Re-signing #{label} for macOS compatibility..."
      ctx.system_command '/usr/bin/codesign', args: ['--force', '--deep', '--sign', '-', app]
    end
  end
end
