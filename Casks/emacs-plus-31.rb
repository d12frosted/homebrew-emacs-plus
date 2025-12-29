cask "emacs-plus-31" do
  version "31-dev-20251229"

  # Architecture and macOS version specific builds
  arch arm: "arm64", intel: "x86_64"

  on_intel do
    depends_on macos: ">= :ventura"
    sha256 "PLACEHOLDER_INTEL_SHA256"
    url "https://github.com/d12frosted/homebrew-emacs-plus/releases/download/v#{version}/emacs-plus-31-x86_64.zip",
        verified: "github.com/d12frosted/homebrew-emacs-plus"
  end

  on_arm do
    depends_on macos: ">= :ventura"

    if MacOS.version >= :tahoe # macOS 26
      sha256 "PLACEHOLDER_ARM64_TAHOE_SHA256"
      url "https://github.com/d12frosted/homebrew-emacs-plus/releases/download/v#{version}/emacs-plus-31-arm64-26.zip",
          verified: "github.com/d12frosted/homebrew-emacs-plus"
    elsif MacOS.version >= :sequoia # macOS 15
      sha256 "PLACEHOLDER_ARM64_SEQUOIA_SHA256"
      url "https://github.com/d12frosted/homebrew-emacs-plus/releases/download/v#{version}/emacs-plus-31-arm64-15.zip",
          verified: "github.com/d12frosted/homebrew-emacs-plus"
    else # macOS 14 (Sonoma) and 13 (Ventura)
      sha256 "PLACEHOLDER_ARM64_SONOMA_SHA256"
      url "https://github.com/d12frosted/homebrew-emacs-plus/releases/download/v#{version}/emacs-plus-31-arm64-14.zip",
          verified: "github.com/d12frosted/homebrew-emacs-plus"
    end
  end

  name "Emacs+ 31"
  desc "GNU Emacs 31 (development) with patches for macOS"
  homepage "https://github.com/d12frosted/homebrew-emacs-plus"

  # Conflict with other Emacs installations
  conflicts_with cask: [
    "emacs",
    "emacs-mac",
    "emacs-mac-spacemacs-icon",
    "emacs-plus",
  ]
  conflicts_with formula: [
    "emacs",
    "emacs-plus@29",
    "emacs-plus@30",
    "emacs-plus@31",
  ]

  # Install the app
  app "Emacs.app"
  app "Emacs Client.app"

  # Symlink binaries
  binary "#{appdir}/Emacs.app/Contents/MacOS/Emacs", target: "emacs"
  binary "#{appdir}/Emacs.app/Contents/MacOS/bin/emacsclient"
  binary "#{appdir}/Emacs.app/Contents/MacOS/bin/ebrowse"
  binary "#{appdir}/Emacs.app/Contents/MacOS/bin/etags"
  binary "#{appdir}/Emacs.app/Contents/MacOS/bin/ctags", target: "emacs-ctags"

  # Man pages
  manpage "#{appdir}/Emacs.app/Contents/Resources/man/man1/emacs.1.gz"
  manpage "#{appdir}/Emacs.app/Contents/Resources/man/man1/emacsclient.1.gz"
  manpage "#{appdir}/Emacs.app/Contents/Resources/man/man1/ebrowse.1.gz"
  manpage "#{appdir}/Emacs.app/Contents/Resources/man/man1/etags.1.gz"

  # Cleanup on uninstall
  zap trash: [
    "~/Library/Caches/org.gnu.Emacs",
    "~/Library/Preferences/org.gnu.Emacs.plist",
    "~/Library/Saved Application State/org.gnu.Emacs.savedState",
    "~/.emacs.d",
  ]

  caveats <<~EOS
    ⚠️  This is a development build from Emacs master branch.

    Emacs+ 31 has been installed to /Applications.

    To change the icon, use epm (Emacs Plus Manager):
      brew install d12frosted/emacs-plus/epm
      epm icon modern-doom

    For custom patches or build options, use the formula instead:
      brew install emacs-plus@31 --with-...
  EOS
end
