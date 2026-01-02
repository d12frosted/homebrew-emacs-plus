require_relative "../Library/EmacsBase"

class EmacsPlusAT30 < EmacsBase
  init 30
  url "https://ftpmirror.gnu.org/emacs/emacs-30.2.tar.xz"
  mirror "https://ftp.gnu.org/gnu/emacs/emacs-30.2.tar.xz"
  sha256 "b3f36f18a6dd2715713370166257de2fae01f9d38cfe878ced9b1e6ded5befd9"

  desc "GNU Emacs text editor"
  homepage "https://www.gnu.org/software/emacs/"

  head do
    if (config_revision = EmacsBase.revision_from_config(30))
      url "https://github.com/emacs-mirror/emacs.git", :revision => config_revision
    elsif ENV['HOMEBREW_EMACS_PLUS_30_REVISION']
      url "https://github.com/emacs-mirror/emacs.git", :revision => ENV['HOMEBREW_EMACS_PLUS_30_REVISION']
    else
      url "https://github.com/emacs-mirror/emacs.git", :branch => "emacs-30"
    end
  end

  #
  # Options
  #

  # Opt-out
  option "without-cocoa", "Build a non-Cocoa version of Emacs"

  # Opt-in
  option "with-ctags", "Don't remove the ctags executable that Emacs provides"
  option "with-x11", "Experimental: build with x11 support"
  option "with-debug", "Build with debug symbols and debugger friendly optimizations"
  option "with-xwidgets", "Experimental: build with xwidgets support"
  option "with-no-frame-refocus", "Disables frame re-focus (ie. closing one frame does not refocus another one)"
  option "with-compress-install", "Build with compressed install optimization"

  #
  # Dependencies
  #

  depends_on "make" => :build
  depends_on "autoconf" => :build
  depends_on "gnu-sed" => :build
  depends_on "gnu-tar" => :build
  depends_on "grep" => :build
  depends_on "awk" => :build
  depends_on "coreutils" => :build
  depends_on "pkg-config" => :build
  depends_on "texinfo" => :build
  depends_on "xz" => :build
  depends_on "m4" => :build
  depends_on "sqlite" => :build
  depends_on "gnutls"
  depends_on "librsvg"
  depends_on "little-cms2"
  depends_on "tree-sitter@0.25"
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

  if build.with? "xwidgets"
    unless (build.with? "cocoa") && (build.without? "x11")
      odie "--with-xwidgets is not available when building --with-x11"
    end
  end

  #
  # URL
  #

  if (config_revision = EmacsBase.revision_from_config(30))
    url "https://github.com/emacs-mirror/emacs.git", :revision => config_revision
  elsif ENV['HOMEBREW_EMACS_PLUS_30_REVISION']
    url "https://github.com/emacs-mirror/emacs.git", :revision => ENV['HOMEBREW_EMACS_PLUS_30_REVISION']
  end

  #
  # Icons
  #

  inject_icon_options

  #
  # Patches
  #

  opoo "The option --with-no-frame-refocus is not required anymore in emacs-plus@30." if build.with? "no-frame-refocus"
  local_patch "fix-window-role", sha: "1f8423ea7e6e66c9ac6dd8e37b119972daa1264de00172a24a79a710efcb8130"
  local_patch "system-appearance", sha: "9eb3ce80640025bff96ebaeb5893430116368d6349f4eb0cb4ef8b3d58477db6"
  local_patch "round-undecorated-frame", sha: "7451f80f559840e54e6a052e55d1100778abc55f98f1d0c038a24e25773f2874"
  local_patch "mac-font-use-typo-metrics", sha: "318395d3869d3479da4593360bcb11a5df08b494b995287074d0d744ec562c17"

  #
  # Install
  #

  def install
    # Check for deprecated --with-*-icon options and auto-migrate
    check_deprecated_icon_option
    # Check icon options are not used with non-Cocoa builds
    check_icon_compatibility
    # Warn if revision is pinned via config or environment variable
    check_pinned_revision(30)
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
    if build.with? "debug"
      ENV.set_debug_symbols
    end

    # Build CFLAGS - pass to configure for includes and defines
    # Note: Homebrew's superenv handles optimization (-O2) and debug (-g) flags
    cflags = []
    cflags << "-DFD_SETSIZE=10000"
    cflags << "-DDARWIN_UNLIMITED_SELECT"
    cflags << "-I#{Formula["sqlite"].include}"
    cflags << "-I#{Formula["gcc"].include}"
    cflags << "-I#{Formula["libgccjit"].include}"
    args << "CFLAGS=#{cflags.join(" ")}"

    ENV.append "LDFLAGS", "-L#{Formula["sqlite"].opt_lib}"
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
      imagemagick_lib_path = Formula["imagemagick"].opt_lib/"pkgconfig"
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
        File.open("src/config.h", "w") do |f|
          f.write(configure_h_filtered)
        end
      end

      system "gmake"

      # Generate dSYM bundle for debugging BEFORE install (clang stores symbols
      # in .o files, and dsymutil needs them to extract debug info)
      if build.with? "debug"
        system "dsymutil", "nextstep/Emacs.app/Contents/MacOS/Emacs"
      end

      system "gmake", "install"

      icons_dir = buildpath/"nextstep/Emacs.app/Contents/Resources"
      ICONS_CONFIG.each_key do |icon|
        next if build.without? "#{icon}-icon"

        rm "#{icons_dir}/Emacs.icns"
        resource("#{icon}-icon").stage do
          icons_dir.install Dir["*.icns*"].first => "Emacs.icns"
        end
      end

      # Apply custom icon from build.yml (if no deprecated --with-*-icon option used)
      unless ICONS_CONFIG.keys.any? { |icon| build.with? "#{icon}-icon" }
        apply_custom_icon(icons_dir)
      end

      # Create Emacs Client.app (AppleScript-based to handle file opening from Finder)
      create_emacs_client_app(icons_dir)

      # (prefix/"share/emacs/#{version}").install "lisp"
      prefix.install "nextstep/Emacs.app"
      (prefix/"Emacs.app/Contents").install "native-lisp"
      prefix.install "nextstep/Emacs Client.app"

      # inject Emacs Plus site-lisp with ns-emacs-plus-version
      inject_emacs_plus_site_lisp(30)

      # inject PATH to Info.plist
      inject_path

      # Rename dSYM to match the binary name (Emacs-real) so lldb auto-finds it
      if build.with? "debug"
        dsym_path = prefix/"Emacs.app/Contents/MacOS/Emacs.dSYM"
        if dsym_path.exist?
          mv dsym_path, prefix/"Emacs.app/Contents/MacOS/Emacs-real.dSYM"
        end
      end

      # inject description for protected resources usage
      inject_protected_resources_usage_desc

      # Replace the symlink with one that avoids starting Cocoa.
      # Check multiple locations so users can copy Emacs.app to /Applications
      # for better Spotlight integration.
      (bin/"emacs").unlink # Kill the existing symlink
      (bin/"emacs").write <<~EOS
        #!/bin/bash
        for app in "/Applications/Emacs.app" "$HOME/Applications/Emacs.app" "#{prefix}/Emacs.app"; do
          if [ -x "$app/Contents/MacOS/Emacs" ]; then
            exec "$app/Contents/MacOS/Emacs" "$@"
          fi
        done
        echo "Error: Emacs.app not found in /Applications, ~/Applications, or #{prefix}" >&2
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
        File.open("src/config.h", "w") do |f|
          f.write(configure_h_filtered)
        end
      end

      system "gmake"

      # Generate dSYM bundle for debugging BEFORE install (non-Cocoa build)
      if build.with? "debug"
        system "dsymutil", "src/emacs"
      end

      system "gmake", "install"
    end

    # Follow MacPorts and don't install ctags from Emacs. This allows Vim
    # and Emacs and ctags to play together without violence.
    if build.without? "ctags"
      (bin/"ctags").unlink
      if build.with? "compress-install"
        (man1/"ctags.1.gz").unlink
      else
        (man1/"ctags.1").unlink
      end
    end
  end

  def post_install
    emacs_info_dir = info/"emacs"
    Dir.glob(emacs_info_dir/"*.info{,.gz}") do |info_filename|
      system "install-info", "--info-dir=#{emacs_info_dir}", info_filename
    end

    # Re-sign the app for macOS Sequoia compatibility (issue #742)
    app_path = prefix/"Emacs.app"
    if app_path.exist?
      ohai "Re-signing Emacs.app for macOS compatibility..."
      system "codesign", "--force", "--deep", "--sign", "-", app_path.to_s
    end
  end

  def caveats
    <<~EOS
      Emacs.app and Emacs Client.app were installed to:
        #{prefix}

      For best Spotlight integration, copy the apps to /Applications:
        cp -r #{prefix}/Emacs.app /Applications/
        cp -r "#{prefix}/Emacs Client.app" /Applications/

      The `emacs` command will automatically find the app in /Applications.

      Alternatively, create Finder aliases (less reliable with Spotlight):
        osascript -e 'tell application "Finder" to make alias file to posix file "#{prefix}/Emacs.app" at posix file "/Applications" with properties {name:"Emacs.app"}'

      Custom icons and patches can be configured via ~/.config/emacs-plus/build.yml
      See: https://github.com/d12frosted/homebrew-emacs-plus/blob/master/community/README.md

      If Emacs fails to start with "Library not loaded" errors after upgrading
      dependencies (e.g., tree-sitter, libgccjit), reinstall emacs-plus:
        brew reinstall emacs-plus@30

      Report any issues to https://github.com/d12frosted/homebrew-emacs-plus
    EOS
  end

  service do
    run [opt_bin/"emacs", "--fg-daemon"]
    keep_alive true
    log_path "/tmp/homebrew.mxcl.emacs-plus.stdout.log"
    error_log_path "/tmp/homebrew.mxcl.emacs-plus.stderr.log"
  end

  test do
    assert_equal "4", shell_output("#{bin}/emacs --batch --eval=\"(print (+ 2 2))\"").strip
  end
end
