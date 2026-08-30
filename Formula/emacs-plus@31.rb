require_relative "../Library/EmacsBase"

class EmacsPlusAT31 < EmacsBase
  init "31.1", sha256: "1da5790d9580c81932b5bf700633114468da7b3412d69faa767daebf974f4586", branch: "emacs-31"

  desc "GNU Emacs text editor"
  homepage "https://www.gnu.org/software/emacs/"

  #
  # Options
  #

  # Opt-out
  option "without-cocoa", "Build a non-Cocoa version of Emacs"

  # Opt-in
  option "with-x11", "Experimental: build with x11 support"
  option "with-debug", "Build with debug symbols and debugger friendly optimizations"
  option "with-xwidgets", "Experimental: build with xwidgets support"
  option "with-compress-install", "Build with compressed install optimization"

  #
  # Dependencies
  #

  depends_on "make" => :build
  depends_on "autoconf" => :build
  depends_on "gnu-sed" => :build
  depends_on "gnu-tar" => :build
  depends_on "grep" => :build
  depends_on "coreutils" => :build
  depends_on "pkg-config" => :build
  depends_on "texinfo" => :build
  depends_on "xz" => :build
  depends_on "m4" => :build
  depends_on "sqlite" => :build
  depends_on "gnutls"
  depends_on "librsvg"
  depends_on "little-cms2"
  depends_on "tree-sitter"
  depends_on "webp"
  depends_on "imagemagick" => :optional
  depends_on "dbus" => :optional
  depends_on "mailutils" => :optional
  # `libgccjit` and `gcc` are required when Emacs compiles `*.elc` files asynchronously (JIT)
  depends_on "libgccjit"
  depends_on "gcc"

  depends_on "gmp" => :build
  depends_on "libjpeg" => :build
  depends_on "zlib" => :build

  if build.with? "x11"
    depends_on "libxaw"
    depends_on "freetype" => :recommended
    depends_on "fontconfig" => :recommended
  end

  #
  # Incompatible options
  #

  if build.with?("xwidgets") && !((build.with? "cocoa") && (build.without? "x11"))
    odie "--with-xwidgets is not available when building --with-x11"
  end

  #
  # Patches
  #

  if build.with? "imagemagick"
    opoo "The option --with-imagemagick is deprecated and will be removed in a future version. " \
         "Modern Emacs has native support for most image formats (SVG via librsvg, WebP, PNG, JPEG, GIF). " \
         "If you rely on ImageMagick, please open an issue describing your use case."
  end
  local_patch "fix-ns-x-colors", sha: "9e5d3e26a8d388d3a000b697d582769645ca93ad597b4113744deba4b89a8b9e"
  local_patch "system-appearance", sha: "53283503db5ed2887e9d733baaaf80f2c810e668e782e988bda5855a0b1ebeb4"
  local_patch "round-undecorated-frame", sha: "c9430a1ead81e313b3d2877ff6f8044fb29441eecc7cc42000515d7c8ec6380f"
  local_patch "fix-ns-scroll-crash", sha: "3250bf6e45cdcb3f4cbc0ace2d2d3200464331cbfb34613980554e31ec45fe6c"

  #
  # Install
  #

  def install
    # Check icon options are not used with non-Cocoa builds
    check_icon_compatibility
    # Warn if revision is pinned via config or environment variable
    check_pinned_revision(31)
    # Validate build.yml configuration early to fail fast
    validate_custom_config

    args = %W[
      --disable-dependency-tracking
      --disable-silent-rules
      --enable-locallisppath=#{HOMEBREW_PREFIX}/share/emacs/site-lisp
      --infodir=#{info}/emacs
      --prefix=#{prefix}
      --with-native-compilation=aot
    ]

    args << "--with-xml2"
    args << "--with-gnutls"

    args << "--without-compress-install" if build.without? "compress-install"

    # Necessary for libgccjit library discovery
    gcc_ver = Formula["gcc"].any_installed_version
    gcc_ver_major = gcc_ver.major
    gcc_lib="#{HOMEBREW_PREFIX}/lib/gcc/#{gcc_ver_major}"

    # Enable debug symbols in Homebrew's superenv
    ENV.set_debug_symbols if build.with? "debug"

    # Build CFLAGS - pass to configure for includes and defines
    # Note: Homebrew's superenv handles optimization (-O2) and debug (-g) flags
    cflags = []
    cflags << "-DFD_SETSIZE=10000"
    cflags << "-DDARWIN_UNLIMITED_SELECT"
    cflags << "-I#{Formula["sqlite"].include}"
    cflags << "-I#{Formula["gcc"].include}"
    cflags << "-I#{Formula["libgccjit"].include}"
    args << "CFLAGS=#{cflags.join(" ")}"

    ENV.append "LDFLAGS", "-L#{Utils::Path.formula_opt_lib("sqlite")}"
    ENV.append "LDFLAGS", "-L#{gcc_lib}"
    ENV.append "LDFLAGS", "-Wl,-rpath,#{gcc_lib}"

    args <<
      if build.with? "dbus"
        "--with-dbus"
      else
        "--without-dbus"
      end

    # Note that if ./configure is passed --with-imagemagick but can't find the
    # library it does not fail but imagemagick support will not be available.
    # See: https://debbugs.gnu.org/cgi/bugreport.cgi?bug=24455
    args <<
      if build.with?("imagemagick")
        "--with-imagemagick"
      else
        "--without-imagemagick"
      end

    if build.with? "imagemagick"
      imagemagick_lib_path = Utils::Path.formula_opt_lib("imagemagick")/"pkgconfig"
      ohai "ImageMagick PKG_CONFIG_PATH: ", imagemagick_lib_path
      ENV.prepend_path "PKG_CONFIG_PATH", imagemagick_lib_path
    end

    args << "--with-modules"
    args << "--with-rsvg"
    args << "--with-webp"
    args << "--without-pop" if build.with? "mailutils"
    args << "--with-xwidgets" if build.with? "xwidgets"

    system "./autogen.sh"

    # Apply custom patches from build.yml
    apply_custom_patches

    if (build.with? "cocoa") && (build.without? "x11")
      args << "--with-ns" << "--disable-ns-self-contained"

      system "./configure", *args

      # Disable aligned_alloc on Mojave. See issue: https://github.com/daviderestivo/homebrew-emacs-head/issues/15
      if OS.mac? && MacOS.version <= :mojave
        ohai "Force disabling of aligned_alloc on macOS <= Mojave"
        configure_h_filtered = File.read("src/config.h")
                                   .gsub("#define HAVE_ALIGNED_ALLOC 1", "#undef HAVE_ALIGNED_ALLOC")
                                   .gsub("#define HAVE_DECL_ALIGNED_ALLOC 1", "#undef HAVE_DECL_ALIGNED_ALLOC")
                                   .gsub("#define HAVE_ALLOCA 1", "#undef HAVE_ALLOCA")
                                   .gsub("#define HAVE_ALLOCA_H 1", "#undef HAVE_ALLOCA_H")
        File.write("src/config.h", configure_h_filtered)
      end

      system "gmake"

      # Generate dSYM bundle for debugging BEFORE install (clang stores symbols
      # in .o files, and dsymutil needs them to extract debug info)
      system "dsymutil", "nextstep/Emacs.app/Contents/MacOS/Emacs" if build.with? "debug"

      system "gmake", "install"

      icons_dir = buildpath/"nextstep/Emacs.app/Contents/Resources"

      # Apply custom icon from build.yml
      apply_custom_icon(icons_dir)

      # Create Emacs Client.app (AppleScript-based to handle file opening from Finder)
      create_emacs_client_app(icons_dir)

      # (prefix/"share/emacs/#{version}").install "lisp"
      prefix.install "nextstep/Emacs.app"
      (prefix/"Emacs.app/Contents").install "native-lisp"
      prefix.install "nextstep/Emacs Client.app"

      # inject Emacs Plus site-lisp with ns-emacs-plus-version
      inject_emacs_plus_site_lisp(31)

      # inject PATH to Info.plist
      inject_path

      # inject description for protected resources usage
      inject_plist_extras

      # Replace the symlink with one that avoids starting Cocoa.
      # Prefer the bundle this formula built; fall back to /Applications and
      # ~/Applications for users who moved Emacs.app there for better
      # Spotlight integration. The fallbacks come last so an Emacs.app
      # installed by the emacs-plus-app cask is never picked up instead of
      # this formula's own build.
      (bin/"emacs").unlink # Kill the existing symlink
      (bin/"emacs").write <<~EOS
        #!/bin/bash
        for app in "#{prefix}/Emacs.app" "/Applications/Emacs.app" "$HOME/Applications/Emacs.app"; do
          if [ -x "$app/Contents/MacOS/Emacs" ]; then
            exec "$app/Contents/MacOS/Emacs" "$@"
          fi
        done
        echo "Error: Emacs.app not found in #{prefix}, /Applications, or ~/Applications" >&2
        exit 1
      EOS
    else
      if build.with? "x11"
        # These libs are not specified in xft's .pc. See:
        # https://trac.macports.org/browser/trunk/dports/editors/emacs/Portfile#L74
        # https://github.com/Homebrew/homebrew/issues/8156
        ENV.append "LDFLAGS", "-lfreetype -lfontconfig"
        args << "--with-x"
        args << "--with-gif=no" << "--with-tiff=no" << "--with-jpeg=no"
      else
        args << "--without-x"
      end
      args << "--without-ns"

      system "./configure", *args

      # Disable aligned_alloc on Mojave. See issue: https://github.com/daviderestivo/homebrew-emacs-head/issues/15
      if OS.mac? && MacOS.version <= :mojave
        ohai "Force disabling of aligned_alloc on macOS <= Mojave"
        configure_h_filtered = File.read("src/config.h")
                                   .gsub("#define HAVE_ALIGNED_ALLOC 1", "#undef HAVE_ALIGNED_ALLOC")
                                   .gsub("#define HAVE_DECL_ALIGNED_ALLOC 1", "#undef HAVE_DECL_ALIGNED_ALLOC")
                                   .gsub("#define HAVE_ALLOCA 1", "#undef HAVE_ALLOCA")
                                   .gsub("#define HAVE_ALLOCA_H 1", "#undef HAVE_ALLOCA_H")
        File.write("src/config.h", configure_h_filtered)
      end

      system "gmake"

      # Generate dSYM bundle for debugging BEFORE install (non-Cocoa build)
      system "dsymutil", "src/emacs" if build.with? "debug"

      system "gmake", "install"
    end
  end

  def post_install
    emacs_info_dir = info/"emacs"
    Dir.glob(emacs_info_dir/"*.info{,.gz}") do |info_filename|
      system "install-info", "--info-dir=#{emacs_info_dir}", info_filename
    end

    # Re-apply icon from build.yml (allows quick testing via `brew postinstall`)
    apply_icon_post_install

    # Re-sign the app for macOS Sequoia compatibility (issue #742)
    app_path = prefix/"Emacs.app"
    if app_path.exist?
      ohai "Re-signing Emacs.app for macOS compatibility..."
      system "codesign", "--force", "--deep", "--sign", "-", app_path.to_s
    end

    # Also re-sign Emacs Client.app
    client_path = prefix/"Emacs Client.app"
    system "codesign", "--force", "--deep", "--sign", "-", client_path.to_s if client_path.exist?
  end

  def caveats
    <<~EOS
      Emacs.app and Emacs Client.app were installed to:
        #{prefix}

      For best Spotlight integration, copy the apps to /Applications:
        cp -r #{prefix}/Emacs.app /Applications/
        cp -r "#{prefix}/Emacs Client.app" /Applications/

      The `emacs` command always runs this formula's own Emacs.app; copies
      in /Applications are only used if the original is removed.

      Alternatively, create Finder aliases (less reliable with Spotlight):
        osascript -e 'tell application "Finder" to make alias file to posix file "#{prefix}/Emacs.app" at posix file "/Applications" with properties {name:"Emacs.app"}'

      Custom icons and patches can be configured via ~/.config/emacs-plus/build.yml
      See: https://github.com/d12frosted/homebrew-emacs-plus/blob/master/community/README.md

      If Emacs fails to start with "Library not loaded" errors after upgrading
      dependencies (e.g., tree-sitter, libgccjit), reinstall emacs-plus:
        brew reinstall emacs-plus@31

      Note: installing this formula alongside an emacs-plus-app cask is not
      supported. Both provide emacs and emacsclient in $(brew --prefix)/bin,
      and Homebrew cannot declare a conflict between a formula and a cask.
      Keep one or the other installed.

      Report any issues to https://github.com/d12frosted/homebrew-emacs-plus
    EOS
  end

  service do
    run [opt_bin/"emacs", "--fg-daemon"]
    keep_alive true
    log_path var/"log/emacs-plus@31.stdout.log"
    error_log_path var/"log/emacs-plus@31.stderr.log"
  end

  test do
    assert_equal "4", shell_output("#{bin}/emacs --batch --eval=\"(print (+ 2 2))\"").strip
  end
end
