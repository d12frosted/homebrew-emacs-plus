cask "emacs-plus-app@next" do
  # Version format: <emacs-version>-<build-number>
  # Build number corresponds to GitHub Actions run number
  version "31.1.50-311"

  # Base URL for release assets (lane releases: cask-next-<build>)
  base_url = "https://github.com/d12frosted/homebrew-emacs-plus/releases/download/cask-next-#{version.sub(/^[\d.]+-/, "")}"
  emacs_ver = version.sub(/-\d+$/, "")

  on_intel do
    sha256 "7d28acfc0d186836b27aee239d63294211fe921020d29d3a64812e088a499f4c"
    url "#{base_url}/emacs-plus-#{emacs_ver}-x86_64-15.zip",
        verified: "github.com/d12frosted/homebrew-emacs-plus"
  end

  on_arm do
    if MacOS.version >= :tahoe # macOS 26
      sha256 "e75de3a5c104d5c0b1ba3e0a98ced9148137cb2376253827361be5d78eb0a540"
      url "#{base_url}/emacs-plus-#{emacs_ver}-arm64-26.zip",
          verified: "github.com/d12frosted/homebrew-emacs-plus"
    elsif MacOS.version >= :sequoia # macOS 15
      sha256 "6fa2220b2837c012672c8b5e7c4ffea98d6d3dffe5d02b307b88a20a532db5b3"
      url "#{base_url}/emacs-plus-#{emacs_ver}-arm64-15.zip",
          verified: "github.com/d12frosted/homebrew-emacs-plus"
    else # macOS 14 (Sonoma) and 13 (Ventura)
      sha256 "f6bdfb924edf0e7a06aadd2006639d13388717fdbf9e68d7648ee6ed8c375461"
      url "#{base_url}/emacs-plus-#{emacs_ver}-arm64-14.zip",
          verified: "github.com/d12frosted/homebrew-emacs-plus"
    end
  end

  name "Emacs+ (Next)"
  desc "GNU Emacs text editor with patches for macOS (Emacs release branch)"
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
    "emacs-plus-app",
    "emacs-plus-app@master",
  ]

  # Install the app
  app "Emacs.app"
  app "Emacs Client.app"

  # Remove quarantine attribute, inject PATH, and apply custom icon
  # (shared logic for all emacs-plus-app casks lives in Library/CaskPostflight.rb)
  postflight do
    tap = Tap.fetch("d12frosted", "emacs-plus")
    load "#{tap.path}/Library/CaskPostflight.rb"
    CaskPostflight.run(self,
                       emacs_app: "#{appdir}/Emacs.app",
                       emacs_client_app: "#{appdir}/Emacs Client.app",
                       version: version.major,
                       homebrew_prefix: HOMEBREW_PREFIX.to_s)
  end

  # Clean up emacs symlink on uninstall (since we create it manually in postflight)
  # Only remove it when it points into this cask's Emacs.app: the formulas
  # link bin/emacs too, and that symlink is not ours to delete
  uninstall_postflight do
    emacs_symlink = "#{HOMEBREW_PREFIX}/bin/emacs"
    if File.symlink?(emacs_symlink) &&
       File.readlink(emacs_symlink).start_with?("#{appdir}/Emacs.app/")
      FileUtils.rm_f(emacs_symlink)
    end
  end

  # Symlink binaries (emacs symlink created in postflight after wrapper is generated)
  # Note: emacs is symlinked manually in postflight because the wrapper script
  # is created there and binary stanzas run before postflight
  # Note: no ctags symlink; the ctags program was removed in Emacs 31
  binary "#{appdir}/Emacs.app/Contents/MacOS/bin/emacsclient"
  binary "#{appdir}/Emacs.app/Contents/MacOS/bin/ebrowse"
  binary "#{appdir}/Emacs.app/Contents/MacOS/bin/etags"

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
  ]

  caveats <<~EOS
    Emacs+ (next) has been installed to /Applications.

    This is a pre-built binary from the Emacs release branch (currently
    emacs-31). It carries the fixes that land after the last release and
    go into the next one: newer than the stable cask, less bleeding edge
    than @master.
    For custom patches or build options, use the formula instead:
      brew install emacs-plus --HEAD --with-...

    Custom icons can be configured via ~/.config/emacs-plus/build.yml:
      icon: dragon-plus

    To re-apply an icon after changing build.yml:
      brew reinstall --cask emacs-plus-app@next

    Note: Emacs Client.app requires Emacs to be running as a daemon.
    Add to your Emacs config: (server-start)
  EOS
end
