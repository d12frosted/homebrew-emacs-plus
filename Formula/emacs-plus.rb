class EmacsPlus < Formula
  desc "GNU Emacs text editor"
  homepage "https://www.gnu.org/software/emacs/"
  url "https://ftp.gnu.org/gnu/emacs/emacs-25.3.tar.xz"
  mirror "https://ftpmirror.gnu.org/emacs/emacs-25.3.tar.xz"
  sha256 "253ac5e7075e594549b83fd9ec116a9dc37294d415e2f21f8ee109829307c00b"

  bottle do
    root_url "https://dl.bintray.com/d12frosted/emacs-plus"
    sha256 "864e5e3954c4e8a48698909591bcfcedf29fb30a783ed4e848f3fdef0548ce03" => :sierra
  end

  devel do
    url "https://alpha.gnu.org/gnu/emacs/pretest/emacs-26.0.90.tar.xz"
    sha256 "efb27124cb8f3eeba9472f4f5774b5d9bf4f87fd4d6023aae78469fb5667cf2c"
  end

  head do
    url "https://github.com/emacs-mirror/emacs.git"

    depends_on "autoconf" => :build
    depends_on "gnu-sed" => :build
    depends_on "texinfo" => :build
  end

  # Opt-out
  option "without-cocoa",
         "Build a non-Cocoa version of Emacs"
  option "without-libxml2",
         "Build without libxml2 support"
  option "without-modules",
         "Build without dynamic modules support"
  option "without-spacemacs-icon",
         "Build without Spacemacs icon by Nasser Alshammari"
  option "without-multicolor-fonts",
         "Build without a patch that enables multicolor font support"

  # Opt-in
  option "with-ctags",
         "Don't remove the ctags executable that Emacs provides"

  # Emacs 25.x and Emacs 26.x experimental stuff
  option "with-x11",
         "Experimental: build with x11 support"

  # Emacs 25.x only
  option "with-24bit-color",
         "Experimental: build with 24 bit color support (stable only)"
  option "with-pixel-scrolling",
         "Build with a patch from emacs-mac supporting native pixel scrolling (stable only)"
  option "with-natural-title-bar",
         "Experimental: use a title bar colour inferred by your theme (stable only)"
  option "with-no-title-bars",
         "Experimental: build with a patch for no title bars on frames (--HEAD and --devel has this built-in via undecorated flag)"

  deprecated_option "cocoa" => "with-cocoa"
  deprecated_option "keep-ctags" => "with-ctags"
  deprecated_option "with-d-bus" => "with-dbus"

  depends_on "pkg-config" => :build
  depends_on :x11 => :optional
  depends_on "dbus" => :optional
  depends_on "gnutls" => :recommended
  depends_on "librsvg" => :recommended
  # Emacs does not support ImageMagick 7:
  # Reported on 2017-03-04: https://debbugs.gnu.org/cgi/bugreport.cgi?bug=25967
  depends_on "imagemagick@6" => :recommended
  depends_on "mailutils" => :optional

  if build.with? "x11"
    depends_on "freetype" => :recommended
    depends_on "fontconfig" => :recommended
  end

  if build.with? "multicolor-fonts"
    patch do
      url "https://gist.githubusercontent.com/aatxe/260261daf70865fbf1749095de9172c5/raw/214b50c62450be1cbee9f11cecba846dd66c7d06/patch-multicolor-font.diff"
      sha256 "5af2587e986db70999d1a791fca58df027ccbabd75f45e4a2af1602c75511a8c"
    end
  end

  # borderless patch
  # remove once it's merged to Emacs
  # more info here: https://lists.gnu.org/archive/html/bug-gnu-emacs/2016-10/msg00072.html
  if build.with? "no-title-bars"
    if build.head? or build.devel?
      odie "--with-no-title-bars is unnecessary on --HEAD or --devel, try (setq default-frame-alist '((undecorated . t)))"
    end

    patch do
      url "https://raw.githubusercontent.com/braham-snyder/GNU-Emacs-OS-X-no-title-bar/master/GNU-Emacs-OS-X-no-title-bar.patch"
      sha256 "2cdb12a73d8e209ce3195e663d6012d1d039eb2880e3c1b9d4e10b77e90ada52"
    end
  end

  if build.with? "natural-title-bar"
    if build.head? or build.devel?
      odie "--with-natural-title-bars is unnecessary on --HEAD or --devel, try (setq 'default-frame-alist '((ns-transparent-titlebar . t) (ns-appearance . 'nil)))"
    end

    patch do
      url "https://gist.githubusercontent.com/jwintz/853f0075cf46770f5ab4f1dbf380ab11/raw/bc30bd2e9a7bf6873f3a3e301d0085bcbefb99b0/emacs_dark_title_bar.patch"
      sha256 "742f7275f3ada695e32735fa02edf91a2ae7b1fa87b7e5f5c6478dd591efa162"
    end
  end

  if build.with? "pixel-scrolling"
    if build.head? or build.devel?
      odie "--with-pixel-scrolling is not support on non-stable version of Emacs"
    end

    patch do
      url "https://gist.githubusercontent.com/aatxe/ecd14e3e4636524915eab2c976650576/raw/c20527ab724ddbeb14db8cc01324410a5a722b18/emacs-pixel-scrolling.patch"
      sha256 "34654d889e8a02aedc0c39a0f710b3cc17d5d4201eb9cb357ecca6ed1ec24684"
    end
  end

  # 24 bit color patch
  # remove after 26.1 is released
  # See https://gist.github.com/akorobov/2c9f5796c661304b4d8aa64c89d2cd00
  unless build.head? or build.devel?
    if build.with? "24bit-color"
      patch do
        url "https://gist.githubusercontent.com/akorobov/2c9f5796c661304b4d8aa64c89d2cd00/raw/2f7d3ae544440b7e2d3a13dd126b491bccee9dbf/emacs-25.2-term-24bit-colors.diff"
        sha256 "ffe72c57117a6dca10b675cbe3701308683d24b62611048d2e7f80f419820cd0"
      end
    end
  end

  # vfork patch
  # remove after 26.1 is released
  # Backported from https://github.com/emacs-mirror/emacs/commit/a13eaddce2ddbe3ba0b7f4c81715bc0fcdba99f6
  # See http://lists.gnu.org/archive/html/bug-gnu-emacs/2017-04/msg00201.html
  unless build.head? or build.devel?
    patch do
      url "https://gist.githubusercontent.com/aaronjensen/f45894ddf431ecbff78b1bcf533d3e6b/raw/6a5cd7f57341aba673234348d8b0d2e776f86719/Emacs-25-OS-X-use-vfork.patch"
      sha256 "f2fdbc5adab80f1af01ce120cf33e3b0590d7ae29538999287986beb55ec9ada"
    end
  end

  def install
    args = %W[
      --disable-dependency-tracking
      --disable-silent-rules
      --enable-locallisppath=#{HOMEBREW_PREFIX}/share/emacs/site-lisp
      --infodir=#{info}/emacs
      --prefix=#{prefix}
    ]

    if build.with? "libxml2"
      args << "--with-xml2"
    else
      args << "--without-xml2"
    end

    if build.with? "dbus"
      args << "--with-dbus"
    else
      args << "--without-dbus"
    end

    if build.with? "gnutls"
      args << "--with-gnutls"
    else
      args << "--without-gnutls"
    end

    # Note that if ./configure is passed --with-imagemagick but can't find the
    # library it does not fail but imagemagick support will not be available.
    # See: https://debbugs.gnu.org/cgi/bugreport.cgi?bug=24455
    if build.with? "imagemagick@6"
      args << "--with-imagemagick"
    else
      args << "--without-imagemagick"
    end

    args << "--with-modules" if build.with? "modules"
    args << "--with-rsvg" if build.with? "librsvg"
    args << "--without-pop" if build.with? "mailutils"

    if build.head?
      ENV.prepend_path "PATH", Formula["gnu-sed"].opt_libexec/"gnubin"
      system "./autogen.sh"
    end

    if build.with? "cocoa"
      args << "--with-ns" << "--disable-ns-self-contained"
    else
      args << "--without-ns"
    end

    system "./configure", *args
    system "make"
    system "make", "install"

    if build.with? "cocoa"
      # icons
      if build.with? "spacemacs-icon"
        icon_file = "nextstep/Emacs.app/Contents/Resources/Emacs.icns"
        spacemacs_icons = "https://github.com/nashamri/spacemacs-logo/blob/master/spacemacs.icns?raw=true"
        rm "#{icon_file}"
        curl "-L", "#{spacemacs_icons}", "-o", "#{icon_file}"
      end

      prefix.install "nextstep/Emacs.app"

      # Replace the symlink with one that avoids starting Cocoa.
      (bin/"emacs").unlink # Kill the existing symlink
      (bin/"emacs").write <<-EOS.undent
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
      system "make"
      system "make", "install"
    end

    # Follow MacPorts and don't install ctags from Emacs. This allows Vim
    # and Emacs and ctags to play together without violence.
    if build.without? "ctags"
      (bin/"ctags").unlink
      (man1/"ctags.1.gz").unlink
    end
  end

  plist_options manual: "emacs"

  def plist; <<-EOS.undent
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
    <dict>
      <key>Label</key>
      <string>#{plist_name}</string>
      <key>ProgramArguments</key>
      <array>
        <string>#{opt_bin}/emacs</string>
        <string>--daemon</string>
      </array>
      <key>RunAtLoad</key>
      <true/>
    </dict>
    </plist>
    EOS
  end

  test do
    assert_equal "4", shell_output("#{bin}/emacs --batch --eval=\"(print (+ 2 2))\"").strip
  end
end
