require_relative "../Library/EmacsBase"

class EmacsPlusAT28 < EmacsBase
  init 28
  url "https://ftpmirror.gnu.org/emacs/emacs-28.2.tar.xz"
  mirror "https://ftp.gnu.org/gnu/emacs/emacs-28.2.tar.xz"
  sha256 "ee21182233ef3232dc97b486af2d86e14042dbb65bbc535df562c3a858232488"

  desc "GNU Emacs text editor"
  homepage "https://www.gnu.org/software/emacs/"

  head do
    url "https://github.com/emacs-mirror/emacs.git", :branch => "emacs-28"
  end

  #
  # Options
  #

  # Opt-out
  option "without-cocoa", "Build a non-Cocoa version of Emacs"

  # Opt-in
  option "with-ctags", "Don't remove the ctags executable that Emacs provides"
  option "with-x11", "Experimental: build with x11 support"
  option "with-no-titlebar", "Experimental: build without titlebar"
  option "with-no-titlebar-and-round-corners", "Experimental: build without titlebar and round coners"
  option "with-debug", "Build with debug symbols and debugger friendly optimizations"
  option "with-xwidgets", "Experimental: build with xwidgets support"
  option "with-no-frame-refocus", "Disables frame re-focus (ie. closing one frame does not refocus another one)"
  option "with-native-comp", "Build with native compilation"

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
  depends_on "gnutls"
  depends_on "librsvg"
  depends_on "little-cms2"
  depends_on "jansson"
  depends_on "imagemagick" => :optional
  depends_on "dbus" => :optional
  depends_on "mailutils" => :optional

  if build.with? "x11"
    depends_on "libxaw"
    depends_on "freetype" => :recommended
    depends_on "fontconfig" => :recommended
  end

  if build.with? "native-comp"
    # `libgccjit` and `gcc` are required when Emacs compiles `*.elc` files asynchronously (JIT)
    depends_on "libgccjit"
    depends_on "gcc"

    depends_on "gmp" => :build
    depends_on "libjpeg" => :build
    depends_on "zlib" => :build
  end

  #
  # Incompatible options
  #

  if build.with? "xwidgets"
    unless (build.with? "cocoa") && (build.without? "x11")
      odie "--with-xwidgets is not available when building --with-x11"
    end
  end

  if build.with? "no-titlebar"
    if build.with? "no-titlebar-and-round-corners"
      odie "--with-no-titlebar and --with-no-titlebar-and-round-corners are mutually exclusive"
    end
  end

  #
  # Patches
  #

  local_patch "no-titlebar", sha: "2fa80efc5cda7e96d88a5d145c9313092a6e53d38825c41967c745f08778c41b" if build.with? "no-titlebar"
  local_patch "no-titlebar-and-round-corners", sha: "ba7606186fe1b9e675147fed2c8080efa2824dc6679f6a9550b792533aec98be" if build.with? "no-titlebar-and-round-corners"
  local_patch "no-frame-refocus-cocoa", sha: "fb5777dc890aa07349f143ae65c2bcf43edad6febfd564b01a2235c5a15fcabd" if build.with? "no-frame-refocus"
  local_patch "fix-window-role", sha: "1f8423ea7e6e66c9ac6dd8e37b119972daa1264de00172a24a79a710efcb8130"
  local_patch "system-appearance", sha: "d6ee159839b38b6af539d7b9bdff231263e451c1fd42eec0d125318c9db8cd92"

  #
  # Install
  #

  def install
    args = %W[
      --disable-dependency-tracking
      --disable-silent-rules
      --enable-locallisppath=#{HOMEBREW_PREFIX}/share/emacs/site-lisp
      --infodir=#{info}/emacs
      --prefix=#{prefix}
    ]

    args << "--with-xml2"
    args << "--with-gnutls"

    args << "--with-native-compilation" if build.with? "native-comp"

    # Enable debug symbols in Homebrew's superenv
    if build.with? "debug"
      ENV.set_debug_symbols
    end

    # Build CFLAGS - pass to configure for includes and defines
    # Note: Homebrew's superenv handles optimization (-O2) and debug (-g) flags
    cflags = []
    cflags << "-DFD_SETSIZE=10000"
    cflags << "-DDARWIN_UNLIMITED_SELECT"

    # Necessary for libgccjit library discovery
    if build.with? "native-comp"
      gcc_ver = Formula["gcc"].any_installed_version
      gcc_ver_major = gcc_ver.major
      gcc_lib="#{HOMEBREW_PREFIX}/lib/gcc/#{gcc_ver_major}"

      cflags << "-I#{Formula["gcc"].include}"
      cflags << "-I#{Formula["libgccjit"].include}"

      ENV.append "LDFLAGS", "-L#{gcc_lib}"
      ENV.append "LDFLAGS", "-I#{Formula["gcc"].include}"
      ENV.append "LDFLAGS", "-I#{Formula["libgccjit"].include}"
    end

    args << "CFLAGS=#{cflags.join(" ")}"

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
    args << "--without-pop" if build.with? "mailutils"
    args << "--with-xwidgets" if build.with? "xwidgets"

    system "./autogen.sh"

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

      # Apply custom icon from build.yml
      apply_custom_icon(icons_dir)

      # (prefix/"share/emacs/#{version}").install "lisp"
      prefix.install "nextstep/Emacs.app"
      (prefix/"Emacs.app/Contents").install "native-lisp" if build.with? "native-comp"

      # inject PATH to Info.plist
      inject_path

      # inject description for protected resources usage
      inject_protected_resources_usage_desc

      # Replace the symlink with one that avoids starting Cocoa.
      (bin/"emacs").unlink # Kill the existing symlink
      (bin/"emacs").write <<~EOS
        #!/bin/bash
        exec #{prefix}/Emacs.app/Contents/MacOS/Emacs "$@"
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
      (man1/"ctags.1.gz").unlink
    end
  end

  def caveats
    <<~EOS
      Emacs.app was installed to:
        #{prefix}

      To link the application to default Homebrew App location:
        osascript -e 'tell application "Finder" to make alias file to posix file "#{prefix}/Emacs.app" at posix file "/Applications" with properties {name:"Emacs.app"}'

      Your PATH value was injected into Emacs.app via a wrapper script.
      This solves the issue with macOS Sequoia ignoring LSEnvironment in Info.plist.

      To disable PATH injection, set EMACS_PLUS_NO_PATH_INJECTION before running Emacs:
        export EMACS_PLUS_NO_PATH_INJECTION=1

      Report any issues to https://github.com/d12frosted/homebrew-emacs-plus
    EOS
  end

  def post_install
    emacs_info_dir = info/"emacs"
    Dir.glob(emacs_info_dir/"*.info{,.gz}") do |info_filename|
      system "install-info", "--info-dir=#{emacs_info_dir}", info_filename
    end

    if build.with? "native-comp"
      ln_sf "#{Dir[opt_prefix/"lib/emacs/*"].first}/native-lisp", "#{opt_prefix}/Emacs.app/Contents/native-lisp"
    end

    # Re-sign the app for macOS Sequoia compatibility (issue #742)
    app_path = prefix/"Emacs.app"
    if app_path.exist?
      ohai "Re-signing Emacs.app for macOS compatibility..."
      system "codesign", "--force", "--deep", "--sign", "-", app_path.to_s
    end
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
