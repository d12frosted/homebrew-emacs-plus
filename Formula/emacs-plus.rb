class EmacsPlus < Formula
  desc "GNU Emacs text editor"
  homepage "https://www.gnu.org/software/emacs/"
  url "https://ftp.gnu.org/gnu/emacs/emacs-26.1.tar.xz"
  mirror "https://ftpmirror.gnu.org/emacs/emacs-26.1.tar.xz"
  sha256 "1cf4fc240cd77c25309d15e18593789c8dbfba5c2b44d8f77c886542300fd32c"

  bottle do
    root_url "https://dl.bintray.com/d12frosted/emacs-plus"
    rebuild 1
    sha256 "f5dac8ba168d0dc9aa1a17a3c971cab451269a200420033b45a8f09a679d2e5a" => :sierra
    sha256 "048db7c214a2709fb2e3a44e098498fa6c1a1bade0e9e43be6192089fe2165c0" => :high_sierra
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

  # Emacs 26.x and Emacs 27.x experimental stuff
  option "with-x11", "Experimental: build with x11 support"
  option "with-no-titlebar", "Experimental: build without titlebar"
  deprecated_option "with-no-title-bars" => "with-no-titlebar"

  # Emacs 27.x only
  option "with-pdumper",
         "Experimental: build from pdumper branch and with
         increasedremembered_data size (--HEAD only)"
  option "with-xwidgets",
         "Experimental: build with xwidgets support (--HEAD only)"

  # Disable some experimental stuff on Mojave
  if MacOS.full_version == "10.14"
    if build.with? "x11"
      odie "--with-x11 is not supported on Mojave yet"
    end
    if build.with? "no-titlebar"
      odie "--with-no-titlebar is not supported on Mojave yet"
    end
    if build.with? "pdumper"
      odie "--with-pdumper is not supported on Mojave yet"
    end
    if build.with? "xwidgets"
      odie "--with-xwidgets is not supported on Mojave yet"
    end
    unless build.head?
      odie "Mojave supports only building from --HEAD"
    end

    patch do
      url "https://github.com/emacs-mirror/emacs/compare/scratch/ns-drawing.patch"
      sha256 "95aad40f90b3750858c700152d46d5bf5062f12c76d77dd838998c86301fdcb8"
    end

    patch do
      url "http://emacs.1067599.n8.nabble.com/attachment/465838/0/0001-Fix-crash-on-flush-to-display-bug-32812.patch"
      sha256 "5c7b50d594a7e57ab518a2995258513ac474d6606fdb165b0e2346253161256a"
    end
  end

  devel do
    url "https://alpha.gnu.org/gnu/emacs/pretest/emacs-26.1-rc1.tar.xz"
    sha256 "6594e668de00b96e73ad4f168c897fe4bca7c55a4caf19ee20eac54b62a05758"
  end

  head do
    if build.with? "pdumper"
      url "https://github.com/emacs-mirror/emacs.git", :branch => "pdumper"
    else
      url "https://github.com/emacs-mirror/emacs.git"
    end

    depends_on "autoconf" => :build
    depends_on "gnu-sed" => :build
    depends_on "texinfo" => :build
  end

  deprecated_option "cocoa" => "with-cocoa"
  deprecated_option "keep-ctags" => "with-ctags"
  deprecated_option "with-d-bus" => "with-dbus"

  depends_on "pkg-config" => :build
  depends_on "little-cms2" => :recommended
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

  if build.with? "no-titlebar"
    patch do
      url "https://raw.githubusercontent.com/d12frosted/homebrew-emacs-plus/master/patches/borderless-frame-on-macOS.patch"
      sha256 "137d71df50d806c4f2699148c66f88909a3dc3952c0e26e2e55f85da542987d1"
    end
  end

  if build.with? "multicolor-fonts"
    patch do
      url "https://gist.githubusercontent.com/aatxe/260261daf70865fbf1749095de9172c5/raw/214b50c62450be1cbee9f11cecba846dd66c7d06/patch-multicolor-font.diff"
      sha256 "5af2587e986db70999d1a791fca58df027ccbabd75f45e4a2af1602c75511a8c"
    end
  end

  if build.with? "xwidgets"
    unless build.head?
      odie "--with-xwidgets is supported only on --HEAD"
    end
    unless build.with? "cocoa"
      odie "--with-xwidgets is supported only on cocoa via xwidget webkit"
    end
    patch do
      url "https://gist.githubusercontent.com/fuxialexander/0231e994fd27be6dd87db60339238813/raw/b30c2d3294835f41e2c8afa1e63571531a38f3cf/0_all_webkit.patch"
      sha256 "f35b955aef31537d2ff163ec9bfcc2176dbcd0ea64f05440d98ec2988b82ce25"
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

  # wait_reading_process_ouput patch
  # remove after 27.1 is released
  # See https://lists.gnu.org/archive/html/emacs-devel/2018-02/msg00363.html
  unless build.head?
    patch do
      url "https://lists.gnu.org/archive/html/emacs-devel/2018-02/txtshOHDg6PmW.txt"
      sha256 "ba9d9555256f91409c4a7b233c36119514ba3d61f4acdb15d7d017db0fb9f00c"
    end

    patch do
      url "https://lists.gnu.org/archive/html/emacs-devel/2018-02/txtzUNqW9dNDT.txt"
      sha256 "500b437c3ed03e0ef1341b800919aa85cc9a9f13ecbaea8d5fc67bf74510317a"
    end
  end

  if build.with? "pdumper"
    unless build.head?
      odie "--with-pdumper is supported only on --HEAD"
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
    args << "--with-xwidgets" if build.with? "xwidgets"

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
        <string>--fg-daemon</string>
      </array>
      <key>RunAtLoad</key>
      <true/>
      <key>StandardOutPath</key>
      <string>/tmp/homebrew.mxcl.emacs-plus.stdout.log</string>
      <key>StandardErrorPath</key>
      <string>/tmp/homebrew.mxcl.emacs-plus.stderr.log</string>
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

      --natural-title-bar option was removed from this formula, in order to
        duplicate its effect add following line to your init.el file
        (add-to-list 'default-frame-alist '(ns-transparent-titlebar . t))
        (add-to-list 'default-frame-alist '(ns-appearance . dark))
      or:
        (add-to-list 'default-frame-alist '(ns-transparent-titlebar . t))
        (add-to-list 'default-frame-alist '(ns-appearance . light))

      If you are using macOS Mojave, please install emacs-plus with --HEAD
      option. Most of the experimental options are forbidden on Mojave. This is
      temporary solution.

    EOS
  end

  test do
    assert_equal "4", shell_output("#{bin}/emacs --batch --eval=\"(print (+ 2 2))\"").strip
  end
end
