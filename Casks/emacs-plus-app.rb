cask "emacs-plus-app" do
  # Version format: <emacs-version>-<build-number>
  # Build number corresponds to GitHub Actions run number
  version "31.1-319"

  # Base URL for release assets (lane releases: cask-stable-<build>)
  base_url = "https://github.com/d12frosted/homebrew-emacs-plus/releases/download/cask-stable-#{version.sub(/^[\d.]+-/, "")}"
  emacs_ver = version.sub(/-\d+$/, "")

  # The url lives at the top level on purpose. `brew tap` loads every cask
  # on every OS/arch pair, and a cask with no url on Intel fails that
  # check, which broke tapping (#1005). `depends_on arch:` below is what
  # refuses the install on Intel.
  if MacOS.version >= :tahoe # macOS 26
    sha256 "ab63f753bdd30b77664dff9c593f37b179bb3bf16c2960bb6db90499e9a97fbe"
    url "#{base_url}/emacs-plus-#{emacs_ver}-arm64-26.zip"
  elsif MacOS.version >= :sequoia # macOS 15
    sha256 "a81c2224b0f9a714c9bd59fbd8190289f8b0ad672d18717bd853fc21e16fcb99"
    url "#{base_url}/emacs-plus-#{emacs_ver}-arm64-15.zip"
  else # macOS 14 (Sonoma)
    sha256 "ab493fcb480ef48fc6aba05c28d6ccc8c43dfc65100680063b71f4a9dfdc40f9"
    url "#{base_url}/emacs-plus-#{emacs_ver}-arm64-14.zip"
  end

  name "Emacs+"
  desc "GNU Emacs text editor with patches"
  homepage "https://github.com/d12frosted/homebrew-emacs-plus"

  # Conflict with other Emacs cask installations
  conflicts_with cask: [
    "emacs",
    "emacs-mac",
    "emacs-mac-spacemacs-icon",
    "emacs-plus-app@master",
    "emacs-plus-app@next",
  ]
  # Required for native compilation (JIT) at runtime
  # - libgccjit: JIT compilation library
  # - gcc: provides toolchain and libemutls_w.a runtime library
  depends_on formula: "libgccjit"
  depends_on formula: "gcc"
  # Oldest prebuilt arm64 binary targets macOS 14 (built on the macos-14
  # runner), so Ventura cannot run it
  depends_on macos: :sonoma
  # Prebuilt binaries are arm64 only; on Intel use the formula, which builds
  # from source. See https://github.com/d12frosted/homebrew-emacs-plus/issues/1002
  depends_on arch: :arm64

  # Install the app
  app "Emacs.app"
  app "Emacs Client.app"
  # Symlink binaries. emacs itself is a symlink step in postflight_steps:
  # the wrapper it points at is generated there, after binary stanzas ran
  # Note: no ctags symlink; the ctags program was removed in Emacs 31
  binary "#{appdir}/Emacs.app/Contents/MacOS/bin/emacsclient"
  binary "#{appdir}/Emacs.app/Contents/MacOS/bin/ebrowse"
  binary "#{appdir}/Emacs.app/Contents/MacOS/bin/etags"
  # Man pages (not gzipped in the build)
  manpage "#{appdir}/Emacs.app/Contents/Resources/man/man1/emacs.1"
  manpage "#{appdir}/Emacs.app/Contents/Resources/man/man1/emacsclient.1"
  manpage "#{appdir}/Emacs.app/Contents/Resources/man/man1/ebrowse.1"
  manpage "#{appdir}/Emacs.app/Contents/Resources/man/man1/etags.1"

  # Post-install setup: quarantine removal, environment injection, custom
  # icon and re-signing. postflight_steps only takes literal steps, so the
  # Ruby in Library/ runs through scripts/cask-postflight as a `run` step.
  # The step runs in Homebrew's sandbox with a scratch HOME; the build.yml
  # locations are declared so the script can still read them, and network
  # access is for icons pulled from a URL.
  postflight_steps do
    run "{{HOMEBREW_PREFIX}}/Library/Taps/d12frosted/homebrew-emacs-plus/scripts/cask-postflight",
        args:           ["--emacs-app", "{{appdir}}/Emacs.app",
                         "--emacs-client-app", "{{appdir}}/Emacs Client.app",
                         "--version", "{{version.major}}",
                         "--homebrew-prefix", "{{HOMEBREW_PREFIX}}"],
        writable_paths: ["~/.config/emacs-plus", "~/.emacs-plus-build.yml"],
        network_access: true,
        print_stdout:   true
    # bin/emacs points at the wrapper the script generates, which is why it
    # is not a `binary` stanza (those run before postflight). An existing
    # link, such as the one from an emacs-plus formula, is left alone (the
    # step would fail on it otherwise), and uninstall only removes a link
    # that points into this Emacs.app.
    unless_path_exists "bin/emacs", base: :homebrew_prefix do
      symlink "Emacs.app/Contents/MacOS/bin/emacs", "bin/emacs",
              source_base:         :appdir,
              target_base:         :homebrew_prefix,
              remove_on_uninstall: true
    end
  end

  # Cleanup on uninstall
  zap trash: [
    "~/Library/Caches/org.gnu.Emacs",
    "~/Library/Preferences/org.gnu.Emacs.plist",
    "~/Library/Saved Application State/org.gnu.Emacs.savedState",
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

    Note: installing this cask alongside an emacs-plus@N formula is not
    supported. Both provide emacs and emacsclient in $(brew --prefix)/bin,
    and Homebrew cannot declare a conflict between a cask and a formula.
    Keep one or the other installed.
  EOS
end
