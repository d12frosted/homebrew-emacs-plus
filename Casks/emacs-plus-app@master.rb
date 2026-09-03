cask "emacs-plus-app@master" do
  # Version format: <emacs-version>-<build-number>
  # Build number corresponds to GitHub Actions run number
  version "32.0.50-321"

  # Base URL for release assets (lane releases: cask-master-<build>)
  base_url = "https://github.com/d12frosted/homebrew-emacs-plus/releases/download/cask-master-#{version.sub(/^[\d.]+-/, "")}"
  emacs_ver = version.sub(/-\d+$/, "")

  on_arm do
    # Oldest prebuilt arm64 binary targets macOS 14 (built on the macos-14
    # runner), so Ventura cannot run it
    depends_on macos: :sonoma

    if MacOS.version >= :tahoe # macOS 26
      sha256 "97bccf03074c061945401b1876d0591e9b76a763b0719d6f873d66b66a9feeb1"
      url "#{base_url}/emacs-plus-#{emacs_ver}-arm64-26.zip",
          verified: "github.com/d12frosted/homebrew-emacs-plus"
    elsif MacOS.version >= :sequoia # macOS 15
      sha256 "9717e4fa0d313e4fa82a49bda588cca153900d513722180bb89b0bd7425cce15"
      url "#{base_url}/emacs-plus-#{emacs_ver}-arm64-15.zip",
          verified: "github.com/d12frosted/homebrew-emacs-plus"
    else # macOS 14 (Sonoma)
      sha256 "ee436ff89527fbe46de714c2dfa96a510b7a743c440a9d08e5b0a18ed9c96705"
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
    intel_version = "32.0.50-321"
    intel_emacs_ver = intel_version.sub(/-\d+$/, "")
    intel_base_url = base_url.sub(/-\d+$/, "-#{intel_version.sub(/^[\d.]+-/, "")}")

    sha256 "099bb4ba50cd2e5ed3c46b1cbce3a14192afc70466bf4bb07d7f8a5f521dc396"

    url "#{intel_base_url}/emacs-plus-#{intel_emacs_ver}-x86_64-15.zip",
        verified: "github.com/d12frosted/homebrew-emacs-plus"

    # The only Intel build targets macOS 15 (built on the macos-15-intel
    # runner, the sole Intel runner available)
    depends_on macos: :sequoia
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
