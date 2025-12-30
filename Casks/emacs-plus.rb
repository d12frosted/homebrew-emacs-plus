cask "emacs-plus" do
  # Version format: <emacs-version>-<build-number>
  # Build number corresponds to GitHub Actions run number
  version "30.2.50-12"

  # Base URL for release assets
  base_url = "https://github.com/d12frosted/homebrew-emacs-plus/releases/download/cask-#{version.sub(/^[\d.]+-/, "")}"
  emacs_ver = version.sub(/-\d+$/, "")

  on_intel do
    sha256 "c0dea6db307f65152c62027863deb6d6d5bd0b1c574491631845e249be5f4721"
    url "#{base_url}/emacs-plus-#{emacs_ver}-x86_64-15.zip",
        verified: "github.com/d12frosted/homebrew-emacs-plus"
  end

  on_arm do
    if MacOS.version >= :tahoe # macOS 26
      sha256 "923b39feaf1a6ad66716630d57cfe31f188afe377b74b2492e1e31fbba6a0efd"
      url "#{base_url}/emacs-plus-#{emacs_ver}-arm64-26.zip",
          verified: "github.com/d12frosted/homebrew-emacs-plus"
    elsif MacOS.version >= :sequoia # macOS 15
      sha256 "4f470012d34cbea43ccaca982f433eb7a57f7e06122bbea88b9451ecce74a6b2"
      url "#{base_url}/emacs-plus-#{emacs_ver}-arm64-15.zip",
          verified: "github.com/d12frosted/homebrew-emacs-plus"
    else # macOS 14 (Sonoma) and 13 (Ventura)
      sha256 "aec3e32730895dd06bb1d09203600e346fd2fd1c6305c7710ee4df8e724cd068"
      url "#{base_url}/emacs-plus-#{emacs_ver}-arm64-14.zip",
          verified: "github.com/d12frosted/homebrew-emacs-plus"
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
