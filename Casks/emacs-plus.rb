cask "emacs-plus" do
  # Version format: <emacs-version>-<build-number>
  # Build number corresponds to GitHub Actions run number
  version "30-8"

  # TODO: Add Intel and other macOS version builds in Phase 4
  # For now, only ARM64 + Tahoe is supported
  on_intel do
    odie "Intel builds are not yet available. Use the formula instead: brew install emacs-plus@30"
  end

  on_arm do
    if MacOS.version >= :tahoe # macOS 26
      sha256 "609d5f9972908431a58261d17d6611adf874ca1a2d16f4574656e3525af28c61"
      url "https://github.com/d12frosted/homebrew-emacs-plus/releases/download/cask-#{version.sub(/^\d+-/, "")}/emacs-plus-#{version.sub(/-\d+$/, "")}-arm64-26.0.1.zip",
          verified: "github.com/d12frosted/homebrew-emacs-plus"
    else
      odie "Pre-built cask only available for macOS Tahoe (26+) currently. Use the formula instead: brew install emacs-plus@30"
    end
  end

  name "Emacs+"
  desc "GNU Emacs text editor with patches for macOS"
  homepage "https://github.com/d12frosted/homebrew-emacs-plus"

  # Conflict with other Emacs cask installations
  conflicts_with cask: [
    "emacs",
    "emacs-mac",
    "emacs-mac-spacemacs-icon",
  ]

  # Install the app
  app "Emacs.app"
  app "Emacs Client.app"

  # Remove quarantine attribute (app is not code signed)
  postflight do
    system_command "/usr/bin/xattr",
                   args: ["-cr", "#{appdir}/Emacs.app"],
                   sudo: false
    system_command "/usr/bin/xattr",
                   args: ["-cr", "#{appdir}/Emacs Client.app"],
                   sudo: false
  end

  # Symlink binaries
  binary "#{appdir}/Emacs.app/Contents/MacOS/Emacs", target: "emacs"
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
      brew install emacs-plus@30 --with-...

    Note: Emacs Client.app requires Emacs to be running as a daemon.
    Add to your Emacs config: (server-start)
  EOS
end
