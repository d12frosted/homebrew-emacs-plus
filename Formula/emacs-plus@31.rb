require_relative "../Library/EmacsBase"

class EmacsPlusAT31 < EmacsBase
  init 31
  version "31.0.50"

  desc "GNU Emacs text editor"
  homepage "https://www.gnu.org/software/emacs/"

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
  option "with-native-comp", "Build with native compilation"
  option "with-compress-install", "Build with compressed install optimization"
  option "with-poll", "Experimental: use poll() instead of select() to support > 1024 file descriptors`"

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
  depends_on "gnutls"
  depends_on "librsvg"
  depends_on "little-cms2"
  depends_on "jansson"
  depends_on "tree-sitter"
  depends_on "webp"
  depends_on "imagemagick" => :optional
  depends_on "dbus" => :optional
  depends_on "mailutils" => :optional

  if build.with? "x11"
    depends_on "libxaw"
    depends_on "freetype" => :recommended
    depends_on "fontconfig" => :recommended
  end

  if build.with? "native-comp"
    depends_on "libgccjit" => :recommended
    depends_on "gcc" => :build
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

  #
  # URL
  #

  if ENV['HOMEBREW_EMACS_PLUS_31_REVISION']
    url "https://github.com/emacs-mirror/emacs.git", :revision => ENV['HOMEBREW_EMACS_PLUS_31_REVISION']
  else
    url "https://github.com/emacs-mirror/emacs.git", :branch => "master"
  end

  #
  # Icons
  #

  inject_icon_options

  #
  # Patches
  #

  opoo "The option --with-no-frame-refocus is not required anymore in emacs-plus@31." if build.with? "no-frame-refocus"
  local_patch "fix-window-role", sha: "1f8423ea7e6e66c9ac6dd8e37b119972daa1264de00172a24a79a710efcb8130"
  local_patch "system-appearance", sha: "9eb3ce80640025bff96ebaeb5893430116368d6349f4eb0cb4ef8b3d58477db6"
  local_patch "poll", sha: "59e876f82e6fd8e4583bc2456339eda4f989c86b1e16a02b0726702e95f60825" if build.with? "poll"
  local_patch "round-undecorated-frame", sha: "7451f80f559840e54e6a052e55d1100778abc55f98f1d0c038a24e25773f2874"

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

    args << "--with-native-compilation=aot" if build.with? "native-comp"
    args << "--without-compress-install" if build.without? "compress-install"

    ENV.append "CFLAGS", "-g -Og" if build.with? "debug"
    ENV.append "CFLAGS", "-O2 -DFD_SETSIZE=10000 -DDARWIN_UNLIMITED_SELECT"

    # Necessary for libgccjit library discovery
    if build.with? "native-comp"
      gcc_ver = Formula["gcc"].any_installed_version
      gcc_ver_major = gcc_ver.major
      gcc_lib="#{HOMEBREW_PREFIX}/lib/gcc/#{gcc_ver_major}"

      ENV.append "CFLAGS", "-I#{Formula["gcc"].include}"
      ENV.append "CFLAGS", "-I#{Formula["libgccjit"].include}"

      ENV.append "LDFLAGS", "-L#{gcc_lib}"
      ENV.append "LDFLAGS", "-I#{Formula["gcc"].include}"
      ENV.append "LDFLAGS", "-I#{Formula["libgccjit"].include}"
    end

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

    if (build.with? "cocoa") && (build.without? "x11")
      args << "--with-ns" << "--disable-ns-self-contained"

      system "./configure", *args

      # Disable aligned_alloc on Mojave. See issue: https://github.com/daviderestivo/homebrew-emacs-head/issues/15
      if MacOS.version <= :mojave
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

      system "gmake", "install"

      icons_dir = buildpath/"nextstep/Emacs.app/Contents/Resources"
      ICONS_CONFIG.each_key do |icon|
        next if build.without? "#{icon}-icon"

        rm "#{icons_dir}/Emacs.icns"
        resource("#{icon}-icon").stage do
          icons_dir.install Dir["*.icns*"].first => "Emacs.icns"
        end
      end

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
      if MacOS.version <= :mojave
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
    args << "--with-poll" if build.with? "poll"
  end

  def post_install
    emacs_info_dir = info/"emacs"
    Dir.glob(emacs_info_dir/"*.info") do |info_filename|
      system "install-info", "--info-dir=#{emacs_info_dir}", info_filename
    end
  end

  def caveats
    <<~EOS
      Emacs.app was installed to:
        #{prefix}

      To link the application to default Homebrew App location:
        osascript -e 'tell application "Finder" to make alias file to posix file "#{prefix}/Emacs.app" at POSIX file "/Applications" with properties {name:"Emacs.app"}'

      Your PATH value was injected into Emacs.app/Contents/Info.plist

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
