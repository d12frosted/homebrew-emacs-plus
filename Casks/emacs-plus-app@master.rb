cask "emacs-plus-app@master" do
  # Version format: <emacs-version>-<build-number>
  # Build number corresponds to GitHub Actions run number
  version "32.0.50-326"

  # Base URL for release assets (lane releases: cask-master-<build>)
  base_url = "https://github.com/d12frosted/homebrew-emacs-plus/releases/download/cask-master-#{version.sub(/^[\d.]+-/, "")}"
  emacs_ver = version.sub(/-\d+$/, "")

  on_arm do
    # Oldest prebuilt arm64 binary targets macOS 14 (built on the macos-14
    # runner), so Ventura cannot run it
    depends_on macos: :sonoma

    if MacOS.version >= :tahoe # macOS 26
      sha256 "7e8a6aa31233c4a6e7293ffc311ab418ae62c8a9e3fc30f1e147088d3ee3bbbb"
      url "#{base_url}/emacs-plus-#{emacs_ver}-arm64-26.zip",
          verified: "github.com/d12frosted/homebrew-emacs-plus"
    elsif MacOS.version >= :sequoia # macOS 15
      sha256 "f6b3cb4e0754d12d0922ea094deded700bdfacd2bad3d44bae4181b3e44d1763"
      url "#{base_url}/emacs-plus-#{emacs_ver}-arm64-15.zip",
          verified: "github.com/d12frosted/homebrew-emacs-plus"
    else # macOS 14 (Sonoma)
      sha256 "d7c73c8f4a66e3c379689b4e5c0a31e01d325bafd2099c77d4f527fb7a01ce37"
      url "#{base_url}/emacs-plus-#{emacs_ver}-arm64-14.zip",
          verified: "github.com/d12frosted/homebrew-emacs-plus"
    end
  end

  name "Emacs+ (Development)"
  desc "GNU Emacs text editor with patches (development version)"
  homepage "https://github.com/d12frosted/homebrew-emacs-plus"

  # Conflict with other Emacs cask installations
  conflicts_with cask: [
    "emacs",
    "emacs-mac",
    "emacs-mac-spacemacs-icon",
    "emacs-plus-app",
    "emacs-plus-app@next",
  ]
  # Required for native compilation (JIT) at runtime
  # - libgccjit: JIT compilation library
  # - gcc: provides toolchain and libemutls_w.a runtime library
  depends_on formula: "libgccjit"
  depends_on formula: "gcc"
  depends_on :macos
  # Prebuilt binaries are arm64 only; on Intel use the formula, which builds
  # from source. See https://github.com/d12frosted/homebrew-emacs-plus/issues/1002
  depends_on arch: :arm64

  # Install the app
  app "Emacs.app"
  app "Emacs Client.app"
  # Symlink binaries (emacs symlink created in postflight after wrapper is generated)
  # Note: emacs is symlinked manually in postflight because the wrapper script
  # is created there and binary stanzas run before postflight
  binary "#{appdir}/Emacs.app/Contents/MacOS/bin/emacsclient"
  binary "#{appdir}/Emacs.app/Contents/MacOS/bin/ebrowse"
  binary "#{appdir}/Emacs.app/Contents/MacOS/bin/etags"
  # Man pages (not gzipped in the build)
  manpage "#{appdir}/Emacs.app/Contents/Resources/man/man1/emacs.1"
  manpage "#{appdir}/Emacs.app/Contents/Resources/man/man1/emacsclient.1"
  manpage "#{appdir}/Emacs.app/Contents/Resources/man/man1/ebrowse.1"
  manpage "#{appdir}/Emacs.app/Contents/Resources/man/man1/etags.1"

  # Remove quarantine attribute, inject PATH, and apply custom icon
  # (shared logic for all emacs-plus-app casks lives in Library/CaskPostflight.rb)
  postflight do
    tap = Tap.fetch("d12frosted", "emacs-plus")
    load "#{tap.path}/Library/CaskPostflight.rb"
    CaskPostflight.run(self,
                       emacs_app:        "#{appdir}/Emacs.app",
                       emacs_client_app: "#{appdir}/Emacs Client.app",
                       version:          version.major,
                       homebrew_prefix:  HOMEBREW_PREFIX.to_s)
  end

  # Clean up emacs symlink on uninstall (since we create it manually in postflight)
  # Only remove it when it points into this cask's Emacs.app: the formulas
  # link bin/emacs too, and that symlink is not ours to delete
  uninstall_postflight do
    emacs_symlink = "#{HOMEBREW_PREFIX}/bin/emacs"
    if File.symlink?(emacs_symlink) &&
       File.readlink(emacs_symlink).start_with?("#{appdir}/Emacs.app/")
      FileUtils.rm(emacs_symlink)
    end
  end

  # Cleanup on uninstall
  zap trash: [
    "~/Library/Caches/org.gnu.Emacs",
    "~/Library/Preferences/org.gnu.Emacs.plist",
    "~/Library/Saved Application State/org.gnu.Emacs.savedState",
  ]

  caveats <<~EOS
    Emacs+ (development) has been installed to /Applications.

    This is a pre-built binary from the Emacs master branch (Emacs 32).
    For custom patches or build options, use the formula instead:
      brew install emacs-plus@master --with-...

    Custom icons can be configured via ~/.config/emacs-plus/build.yml:
      icon: dragon-plus

    To re-apply an icon after changing build.yml:
      brew reinstall --cask emacs-plus-app@master

    Note: Emacs Client.app requires Emacs to be running as a daemon.
    Add to your Emacs config: (server-start)

    Note: installing this cask alongside an emacs-plus@N formula is not
    supported. Both provide emacs and emacsclient in $(brew --prefix)/bin,
    and Homebrew cannot declare a conflict between a cask and a formula.
    Keep one or the other installed.
  EOS
end
