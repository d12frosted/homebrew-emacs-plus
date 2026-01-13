cask "emacs-plus-app" do
  # Version format: <emacs-version>-<build-number>
  # Build number corresponds to GitHub Actions run number
  version "30.2-54"

  # Base URL for release assets (versioned releases: cask-30-<build>)
  base_url = "https://github.com/d12frosted/homebrew-emacs-plus/releases/download/cask-30-#{version.sub(/^[\d.]+-/, "")}"
  emacs_ver = version.sub(/-\d+$/, "")

  on_intel do
    sha256 "c9e1d87f5e3204e2fbf8c6ff75e71edc3732738f7cf9aabffe0c11368c48b4d9"
    url "#{base_url}/emacs-plus-#{emacs_ver}-x86_64-15.zip",
        verified: "github.com/d12frosted/homebrew-emacs-plus"
  end

  on_arm do
    if MacOS.version >= :tahoe # macOS 26
      sha256 "7a8506e2015464db3148a7e55f8fda3b5f888cba8e95cb7b5ac95ea012211cde"
      url "#{base_url}/emacs-plus-#{emacs_ver}-arm64-26.zip",
          verified: "github.com/d12frosted/homebrew-emacs-plus"
    elsif MacOS.version >= :sequoia # macOS 15
      sha256 "705bdbd837f6f2f987490e10b333440746a12a647095db9290a0116c301625f2"
      url "#{base_url}/emacs-plus-#{emacs_ver}-arm64-15.zip",
          verified: "github.com/d12frosted/homebrew-emacs-plus"
    else # macOS 14 (Sonoma) and 13 (Ventura)
      sha256 "cbd344b89cffe156e15704dd5ead563fbd76821de4920001d446e2f41f311773"
      url "#{base_url}/emacs-plus-#{emacs_ver}-arm64-14.zip",
          verified: "github.com/d12frosted/homebrew-emacs-plus"
    end
  end

  name "Emacs+"
  desc "GNU Emacs text editor with patches for macOS"
  homepage "https://github.com/d12frosted/homebrew-emacs-plus"

  # Required for native compilation (JIT) at runtime
  # - libgccjit: JIT compilation library
  # - gcc: provides toolchain and libemutls_w.a runtime library
  depends_on formula: "libgccjit"
  depends_on formula: "gcc"

  # Conflict with other Emacs cask installations
  conflicts_with cask: [
    "emacs",
    "emacs-mac",
    "emacs-mac-spacemacs-icon",
    "emacs-plus-app@master",
  ]

  # Install the app
  app "Emacs.app"
  app "Emacs Client.app"

  # Remove quarantine attribute, inject PATH, and apply custom icon
  postflight do
    system_command "/usr/bin/xattr",
                   args: ["-cr", "#{appdir}/Emacs.app"],
                   sudo: false
    system_command "/usr/bin/xattr",
                   args: ["-cr", "#{appdir}/Emacs Client.app"],
                   sudo: false

    # Environment setup for native compilation and CLI usage
    tap = Tap.fetch("d12frosted", "emacs-plus")
    load "#{tap.path}/Library/CaskEnv.rb"
    needs_resign = CaskEnv.inject("#{appdir}/Emacs.app", "#{appdir}/Emacs Client.app")

    # Apply custom icon from ~/.config/emacs-plus/build.yml if configured
    load "#{tap.path}/Library/IconApplier.rb"
    needs_resign = IconApplier.apply("#{appdir}/Emacs.app", "#{appdir}/Emacs Client.app") || needs_resign

    if needs_resign
      # Re-sign after modifications
      system_command "/usr/bin/codesign",
                     args: ["--force", "--deep", "--sign", "-", "#{appdir}/Emacs.app"],
                     sudo: false
      system_command "/usr/bin/codesign",
                     args: ["--force", "--deep", "--sign", "-", "#{appdir}/Emacs Client.app"],
                     sudo: false
    end

    # Create emacs symlink manually (can't use binary stanza since wrapper is created above)
    emacs_wrapper = "#{appdir}/Emacs.app/Contents/MacOS/bin/emacs"
    emacs_symlink = "#{HOMEBREW_PREFIX}/bin/emacs"
    if File.exist?(emacs_wrapper) && !File.exist?(emacs_symlink)
      FileUtils.ln_sf(emacs_wrapper, emacs_symlink)
    end
  end

  # Clean up emacs symlink on uninstall (since we create it manually in postflight)
  uninstall_postflight do
    emacs_symlink = "#{HOMEBREW_PREFIX}/bin/emacs"
    FileUtils.rm_f(emacs_symlink) if File.symlink?(emacs_symlink)
  end

  # Symlink binaries (emacs symlink created in postflight after wrapper is generated)
  # Note: emacs is symlinked manually in postflight because the wrapper script
  # is created there and binary stanzas run before postflight
  binary "#{appdir}/Emacs.app/Contents/MacOS/bin/emacsclient"
  binary "#{appdir}/Emacs.app/Contents/MacOS/bin/ebrowse"
  binary "#{appdir}/Emacs.app/Contents/MacOS/bin/etags"
  binary "#{appdir}/Emacs.app/Contents/MacOS/bin/ctags", target: "emacs-ctags"

  # Man pages (not gzipped in the build)
  manpage "#{appdir}/Emacs.app/Contents/Resources/man/man1/emacs.1"
  manpage "#{appdir}/Emacs.app/Contents/Resources/man/man1/emacsclient.1"
  manpage "#{appdir}/Emacs.app/Contents/Resources/man/man1/ebrowse.1"
  manpage "#{appdir}/Emacs.app/Contents/Resources/man/man1/etags.1"

  # Cleanup on uninstall
  zap trash: [
    "~/Library/Caches/org.gnu.Emacs",
    "~/Library/Preferences/org.gnu.Emacs.plist",
    "~/Library/Saved Application State/org.gnu.Emacs.savedState",
    "~/.emacs.d",
  ]

  caveats <<~EOS
    Emacs+ has been installed to /Applications.

    This is a pre-built binary. For custom patches or build options,
    use the formula instead:
      brew install emacs-plus --with-...

    Custom icons can be configured via ~/.config/emacs-plus/build.yml:
      icon: dragon-plus

    To re-apply an icon after changing build.yml:
      brew reinstall --cask emacs-plus-app

    Note: Emacs Client.app requires Emacs to be running as a daemon.
    Add to your Emacs config: (server-start)
  EOS
end
