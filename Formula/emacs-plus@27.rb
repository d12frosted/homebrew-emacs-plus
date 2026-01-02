require_relative "../Library/EmacsBase"

class EmacsPlusAT27 < EmacsBase
  init 27
  url "https://ftpmirror.gnu.org/emacs/emacs-27.2.tar.xz"
  mirror "https://ftp.gnu.org/gnu/emacs/emacs-27.2.tar.xz"
  sha256 "b4a7cc4e78e63f378624e0919215b910af5bb2a0afc819fad298272e9f40c1b9"

  desc "GNU Emacs text editor"
  homepage "https://www.gnu.org/software/emacs/"

  head do
    url "https://github.com/emacs-mirror/emacs.git", :branch => "emacs-27"
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
  option "with-debug", "Build with debug symbols and debugger friendly optimizations"
  option "with-xwidgets", "Experimental: build with xwidgets support"
  option "with-no-frame-refocus", "Disables frame re-focus (ie. closing one frame does not refocus another one)"

  #
  # Dependencies
  #

  depends_on "autoconf" => :build
  depends_on "gnu-sed" => :build
  depends_on "pkg-config" => :build
  depends_on "texinfo" => :build
  depends_on "gnutls"
  depends_on "librsvg"
  depends_on "little-cms2"
  depends_on "jansson"
  depends_on "imagemagick" => :recommended
  depends_on "dbus" => :optional
  depends_on "mailutils" => :optional

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
  # Icons
  #

  inject_icon_options

  #
  # Patches
  #

  local_patch "no-titlebar", sha: "fdf8dde63c2e1c4cb0b02354ce7f2102c5f8fd9e623f088860aee8d41d7ad38f" if build.with? "no-titlebar"
  local_patch "xwidgets_webkit_in_cocoa", sha: "683b09c5f91d1ed3a550d10f409647e4ed236d4352464d15baef871546622e40" if build.with? "xwidgets"
  local_patch "no-frame-refocus-cocoa", sha: "fb5777dc890aa07349f143ae65c2bcf43edad6febfd564b01a2235c5a15fcabd" if build.with? "no-frame-refocus"
  local_patch "fix-window-role", sha: "1f8423ea7e6e66c9ac6dd8e37b119972daa1264de00172a24a79a710efcb8130"
  local_patch "system-appearance", sha: "d774e9da082352999fe3e9d2daa1065ea9bdaa670267caeebf86e01a77dc1d40"
  local_patch "ligatures-freeze-fix", sha: "782a222505ceea31f9032ed55e24dcbd0357b1178b916b536d3eb222c9dc1225"
  local_patch "arm", sha: "344fee330fec4071e29c900093fdf1e2d8a7328df1c75b17e6e9d9a954835741" if build.stable?

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

    # Enable debug symbols in Homebrew's superenv
    if build.with? "debug"
      ENV.set_debug_symbols
    end

    # Build CFLAGS - pass to configure for includes and defines
    # Note: Homebrew's superenv handles optimization (-O2) and debug (-g) flags
    cflags = []
    cflags << "-DFD_SETSIZE=10000"
    cflags << "-DDARWIN_UNLIMITED_SELECT"
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

    ENV.prepend_path "PATH", Formula["gnu-sed"].opt_libexec/"gnubin"
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

      system "make"

      # Generate dSYM bundle for debugging BEFORE install (clang stores symbols
      # in .o files, and dsymutil needs them to extract debug info)
      if build.with? "debug"
        system "dsymutil", "nextstep/Emacs.app/Contents/MacOS/Emacs"
      end

      system "make", "install"

      icons_dir = buildpath/"nextstep/Emacs.app/Contents/Resources"
      ICONS_CONFIG.each_key do |icon|
        next if build.without? "#{icon}-icon"

        rm "#{icons_dir}/Emacs.icns"
        resource("#{icon}-icon").stage do
          icons_dir.install Dir["*.icns*"].first => "Emacs.icns"
        end
      end

      prefix.install "nextstep/Emacs.app"

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

      system "make"

      # Generate dSYM bundle for debugging BEFORE install (non-Cocoa build)
      if build.with? "debug"
        system "dsymutil", "src/emacs"
      end

      system "make", "install"
    end

    # Follow MacPorts and don't install ctags from Emacs. This allows Vim
    # and Emacs and ctags to play together without violence.
    if build.without? "ctags"
      (bin/"ctags").unlink
      (man1/"ctags.1.gz").unlink
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
      Emacs.app was installed to:
        #{prefix}

      To link the application to default Homebrew App location:
        osascript -e 'tell application "Finder" to make alias file to posix file "#{prefix}/Emacs.app" at posix file "/Applications" with properties {name:"Emacs.app"}'

      If you wish to install Emacs 26 or Emacs 28, use emacs-plus@26 or
      emacs-plus@28 formula respectively.
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
