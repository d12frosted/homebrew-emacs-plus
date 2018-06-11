class EmacsPlusAT25 < Formula
  desc "GNU Emacs text editor"
  homepage "https://www.gnu.org/software/emacs/"
  url "https://ftp.gnu.org/gnu/emacs/emacs-25.3.tar.xz"
  sha256 "253ac5e7075e594549b83fd9ec116a9dc37294d415e2f21f8ee109829307c00b"
  revision 2

  bottle do
    root_url "https://dl.bintray.com/d12frosted/emacs-plus"
    sha256 "223cb092edd4548e91545919c1445aa4961ef0b7e352d9249caa4fd5afa45f25" => :sierra
    sha256 "a827b6be3b2cb6d164aac3498bac1db494caf8df9bb2f16df91c51b6e29267cf" => :high_sierra
  end

  devel do
    url "https://alpha.gnu.org/gnu/emacs/pretest/emacs-26.1-rc1.tar.xz"
    sha256 "6594e668de00b96e73ad4f168c897fe4bca7c55a4caf19ee20eac54b62a05758"
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

  # Update list from
  # https://raw.githubusercontent.com/emacsfodder/emacs-icons-project/master/icons.json
  #
  # code taken from emacs-mac formula
  emacs_icons_project_icons = {
    "EmacsIcon1" => "50dbaf2f6d67d7050d63d987fe3743156b44556ab42e6d9eee92248c56011bd0",
    "EmacsIcon2" => "8d63589b0302a67f13ab94b91683a8ad7c2b9e880eabe008056a246a22592963",
    "EmacsIcon3" => "80dd2a4776739a081e0a42008e8444c729d41ba876b19fa9d33fde98ee3e0ebf",
    "EmacsIcon4" => "8ce646ca895abe7f45029f8ff8f5eac7ab76713203e246b70dea1b8a21a6c135",
    "EmacsIcon5" => "ca415df7ad60b0dc495626b0593d3e975b5f24397ad0f3d802455c3f8a3bd778",
    "EmacsIcon6" => "12a1999eb006abac11535b7fe4299ebb3c8e468360faf074eb8f0e5dec1ac6b0",
    "EmacsIcon7" => "f5067132ea12b253fb4a3ea924c75352af28793dcf40b3063bea01af9b2bd78c",
    "EmacsIcon8" => "d330b15cec1bcdfb8a1e8f8913d8680f5328d59486596fc0a9439b54eba340a0",
    "EmacsIcon9" => "f58f46e5ef109fff8adb963a97aea4d1b99ca09265597f07ee95bf9d1ed4472e",
    "emacs-card-blue-deep" => "6bdb17418d2c620cf4132835cfa18dcc459a7df6ce51c922cece3c7782b3b0f9",
    "emacs-card-british-racing-green" => "ddf0dff6a958e3b6b74e6371f1a68c2223b21e75200be6b4ac6f0bd94b83e1a5",
    "emacs-card-carmine" => "4d34f2f1ce397d899c2c302f2ada917badde049c36123579dd6bb99b73ebd7f9",
    "emacs-card-green" => "f94ade7686418073f04b73937f34a1108786400527ed109af822d61b303048f7",
  }

  emacs_icons_project_icons.keys.each do |icon|
    option "with-emacs-icons-project-#{icon}", "Using Emacs icon project #{icon}"
  end

  option "with-modern-icon", "Using a modern style Emacs icon by @tpanum"

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

  resource "modern-icon" do
    url "https://s3.amazonaws.com/emacs-mac-port/Emacs.icns.modern"
    sha256 "eb819de2380d3e473329a4a5813fa1b4912ec284146c94f28bd24fbb79f8b2c5"
  end

  resource "spacemacs-icon" do
    url "https://github.com/nashamri/spacemacs-logo/blob/master/spacemacs.icns?raw=true"
    sha256 "b3db8b7cfa4bc5bce24bc4dc1ede3b752c7186c7b54c09994eab5ec4eaa48900"
  end

  emacs_icons_project_icons.each do |icon, sha|
    resource "emacs-icons-project-#{icon}" do
      url "https://raw.githubusercontent.com/emacsfodder/emacs-icons-project/master/#{icon}.icns"
      sha256 sha
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
      odie "--with-natural-title-bars is unnecessary on --HEAD or --devel, try (setq default-frame-alist '((ns-transparent-titlebar . t) (ns-appearance . 'nil)))"
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

  # wait_reading_process_ouput patch
  # remove after it's released
  # and apply to master once 26.1 is released
  # See https://lists.gnu.org/archive/html/emacs-devel/2018-02/msg00363.html
  if build.devel?
    patch do
      url "https://lists.gnu.org/archive/html/emacs-devel/2018-02/txtshOHDg6PmW.txt"
      sha256 "ba9d9555256f91409c4a7b233c36119514ba3d61f4acdb15d7d017db0fb9f00c"
    end

    patch do
      url "https://lists.gnu.org/archive/html/emacs-devel/2018-02/txtzUNqW9dNDT.txt"
      sha256 "500b437c3ed03e0ef1341b800919aa85cc9a9f13ecbaea8d5fc67bf74510317a"
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

      system "./configure", *args
      system "make"
      system "make", "install"

      icons_dir = buildpath/"nextstep/Emacs.app/Contents/Resources"

      (%w[EmacsIcon1 EmacsIcon2 EmacsIcon3 EmacsIcon4
        EmacsIcon5 EmacsIcon6 EmacsIcon7 EmacsIcon8
        EmacsIcon9 emacs-card-blue-deep emacs-card-british-racing-green
        emacs-card-carmine emacs-card-green].map { |i| "emacs-icons-project-#{i}" } +
       %w[modern-icon spacemacs-icon]).each do |icon|
        next if build.without? icon

        rm "#{icons_dir}/Emacs.icns"
        resource(icon).stage do
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

  def plist; <<~EOS
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

  def caveats
    <<~EOS
      Emacs.app was installed to:
        #{prefix}

      To link the application to default Homebrew App location:
        brew linkapps
      or:
        ln -s #{prefix}/Emacs.app /Applications
    EOS
  end

  test do
    assert_equal "4", shell_output("#{bin}/emacs --batch --eval=\"(print (+ 2 2))\"").strip
  end
end
