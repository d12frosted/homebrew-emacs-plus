cask "emacs-plus-app@next" do
  # Version format: <emacs-version>-<build-number>
  # Build number corresponds to GitHub Actions run number
  version "31.1.50-321"

  # Base URL for release assets (lane releases: cask-next-<build>)
  base_url = "https://github.com/d12frosted/homebrew-emacs-plus/releases/download/cask-next-#{version.sub(/^[\d.]+-/, "")}"
  emacs_ver = version.sub(/-\d+$/, "")

  on_arm do
    # Oldest prebuilt arm64 binary targets macOS 14 (built on the macos-14
    # runner), so Ventura cannot run it
    depends_on macos: :sonoma

    if MacOS.version >= :tahoe # macOS 26
      sha256 "cc4c41746ebd47f84e6bb1f34759a63f37222e7f0729ce073f635a544cb8f7fb"
      url "#{base_url}/emacs-plus-#{emacs_ver}-arm64-26.zip",
          verified: "github.com/d12frosted/homebrew-emacs-plus"
    elsif MacOS.version >= :sequoia # macOS 15
      sha256 "08b1a6876a382224c7242368ed11417fe7b333d05aa665969cfcdfe8b932c589"
      url "#{base_url}/emacs-plus-#{emacs_ver}-arm64-15.zip",
          verified: "github.com/d12frosted/homebrew-emacs-plus"
    else # macOS 14 (Sonoma)
      sha256 "1a47a954a075e8e82bbf3141bc4cc0c35db5f7b4dcdded570b53d13eda4cfc0c"
      url "#{base_url}/emacs-plus-#{emacs_ver}-arm64-14.zip",
          verified: "github.com/d12frosted/homebrew-emacs-plus"
    end
  end
  on_intel do
    # Intel assets can lag behind the arm64 ones. Homebrew treats x86_64 macOS
    # as a tier 3 configuration and stopped bottling some dependencies for it,
    # so the Intel build breaks on its own schedule and a release can ship
    # without it. This pin points at the last release that did produce an Intel
    # binary, so it is expected to trail the version above from time to time.
    intel_version = "31.1.50-321"
    intel_emacs_ver = intel_version.sub(/-\d+$/, "")
    intel_base_url = base_url.sub(/-\d+$/, "-#{intel_version.sub(/^[\d.]+-/, "")}")

    sha256 "bd05b26b913c717267f2594e007ed13ecf6827011d2173d62913fb96efc74ab5"

    url "#{intel_base_url}/emacs-plus-#{intel_emacs_ver}-x86_64-15.zip",
        verified: "github.com/d12frosted/homebrew-emacs-plus"

    # The only Intel build targets macOS 15 (built on the macos-15-intel
    # runner, the sole Intel runner available)
    depends_on macos: :sequoia
  end

  name "Emacs+ (Next)"
  desc "GNU Emacs text editor with patches (Emacs release branch)"
  homepage "https://github.com/d12frosted/homebrew-emacs-plus"

  # Conflict with other Emacs cask installations
  conflicts_with cask: [
    "emacs",
    "emacs-mac",
    "emacs-mac-spacemacs-icon",
    "emacs-plus-app",
    "emacs-plus-app@master",
  ]
  # Required for native compilation (JIT) at runtime
  # - libgccjit: JIT compilation library
  # - gcc: provides toolchain and libemutls_w.a runtime library
  depends_on formula: "libgccjit"
  depends_on formula: "gcc"
  depends_on :macos

  # Install the app
  app "Emacs.app"
  app "Emacs Client.app"
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

    Note: installing this cask alongside an emacs-plus@N formula is not
    supported. Both provide emacs and emacsclient in $(brew --prefix)/bin,
    and Homebrew cannot declare a conflict between a cask and a formula.
    Keep one or the other installed.
  EOS
end
