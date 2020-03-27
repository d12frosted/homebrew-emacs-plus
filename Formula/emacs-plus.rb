# coding: utf-8
class PatchUrlResolver
  def self.repo
    ENV["HOMEBREW_GITHUB_REPOSITORY"] or "d12frosted/homebrew-emacs-plus"
  end

  def self.branch
    ref = ENV["HOMEBREW_GITHUB_REF"]
    if ref
      ref.sub("refs/heads/", "")
    else
      "master"
    end
  end

  def self.url name
    "https://raw.githubusercontent.com/#{repo}/#{branch}/patches/#{name}.patch"
  end
end

class EmacsPlus < Formula
  desc "GNU Emacs text editor"
  homepage "https://www.gnu.org/software/emacs/"
  url "https://ftp.gnu.org/gnu/emacs/emacs-26.3.tar.xz"
  mirror "https://ftpmirror.gnu.org/emacs/emacs-26.3.tar.xz"
  sha256 "4d90e6751ad8967822c6e092db07466b9d383ef1653feb2f95c93e7de66d3485"

  bottle do
    root_url "https://dl.bintray.com/d12frosted/emacs-plus"
    sha256 "6b59ea5c941b754f5008039be319e4437ebd66dc2e1a50fdf890cf226c078386" => :mojave
    sha256 "cb589861c8a697869107d1cbacc9cc920a8e7257b5c371b7e590b05e7e04c92c" => :catalina
  end

  #
  # Options
  #

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
  option "with-x11", "Experimental: build with x11 support"
  option "with-no-titlebar", "Experimental: build without titlebar"
  option "with-debug",
         "Build with debug symbols and debugger friendly optimizations"

  # Emacs 27.x only
  option "with-xwidgets",
         "Experimental: build with xwidgets support (--HEAD only)"
  option "with-jansson",
         "Build with jansson support (--HEAD only)"
  option "with-emacs-27-branch",
         "Build from emacs-27-branch (--HEAD only)"
  option "with-native-comp-branch",
         "Build from native-comp branch (--HEAD only)"

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

  option "with-gnu-head-icon", "Using a Bold GNU Head icon by Aurélio A. Heckert"

  option "with-no-frame-refocus", "Disables frame re-focus (ie. closing one frame does not refocus another one)"

  # Deprecated options
  deprecated_option "cocoa" => "with-cocoa"
  deprecated_option "keep-ctags" => "with-ctags"
  deprecated_option "with-d-bus" => "with-dbus"
  deprecated_option "with-no-title-bars" => "with-no-titlebar"

  #
  # URLs
  #

  head do
    if build.with? "emacs-27-branch"
      url "https://github.com/emacs-mirror/emacs.git", :branch => "emacs-27"
    elsif build.with? "native-comp-branch"
      url "https://github.com/emacs-mirror/emacs.git", :branch => "feature/native-comp"
    else
      url "https://github.com/emacs-mirror/emacs.git"
    end
  end

  #
  # Dependencies
  #

  head do
    depends_on "autoconf" => :build
    depends_on "gnu-sed" => :build
    depends_on "texinfo" => :build
  end

  depends_on "pkg-config" => :build
  depends_on "little-cms2" => :recommended
  depends_on :x11 => :optional
  depends_on "dbus" => :optional
  depends_on "gnutls" => :recommended
  depends_on "librsvg" => :recommended
  depends_on "mailutils" => :optional

  if build.head?
    # Emacs 27.x (current HEAD) does support ImageMagick 7
    depends_on "imagemagick@7" => :recommended
    depends_on "imagemagick@6" => :optional
  else
    # Emacs 26.x does not support ImageMagick 7:
    # Reported on 2017-03-04: https://debbugs.gnu.org/cgi/bugreport.cgi?bug=25967
    depends_on "imagemagick@6" => :recommended
  end

  depends_on "jansson" => :optional

  if build.with? "x11"
    depends_on "freetype" => :recommended
    depends_on "fontconfig" => :recommended
  end

  #
  # Incompatible options
  #

  if build.with? "emacs-27-branch"
    unless build.head?
      odie "--with-emacs-27-branch is supported only on --HEAD"
    end
  end

  if build.with? "native-comp-branch"
    unless build.head?
      odie "--with-native-comp-branch is supported only on --HEAD"
    end
  end

  if build.with? "xwidgets"
    unless build.head?
      odie "--with-xwidgets is supported only on --HEAD"
    end
    unless build.with? "cocoa" and build.without? "x11"
      odie "--with-xwidgets is supported only on cocoa via xwidget webkit"
    end
  end

  #
  # Patches
  #

  if build.with? "no-titlebar"
    if build.with? "emacs-27-branch"
      patch do
        url (PatchUrlResolver.url "no-titlebar-emacs-27")
        sha256 "fdf8dde63c2e1c4cb0b02354ce7f2102c5f8fd9e623f088860aee8d41d7ad38f"
      end
    elsif build.head?
      patch do
        url (PatchUrlResolver.url "no-titlebar-head")
        sha256 "d4645c7d2ca42b5e6fb45e1da8d98a5ed6bf126455f9e7118e2cc650c5df174c"
      end
    else
      patch do
        url (PatchUrlResolver.url "no-titlebar-release")
        sha256 "2059213cc740a49b131a363d6093913fa29f8f67227fc86a82ffe633bbf1a5f5"
      end
    end
  end

  if build.with? "multicolor-fonts"
    unless build.head?
      patch do
        url (PatchUrlResolver.url "multicolor-fonts")
        sha256 "7597514585c036c01d848b1b2cc073947518522ba6710640b1c027ff47c99ca7"
      end
    end
  end

  if build.with? "xwidgets"
    patch do
      url (PatchUrlResolver.url "xwidgets_webkit_in_cocoa")
      sha256 "6376e9e40686077b67c0e21115f0aa451b63ea5d8ee996a69f95cb3f693c9174"
    end
  end

  if build.with? "no-frame-refocus"
    patch do
      url (PatchUrlResolver.url "no-frame-refocus-cocoa")
      sha256 "a140fa44eab0cf47b4fcc8cfb96132a8b40a4ba37b2e84b8c78129dbf6ca632c"
    end
  end

  patch do
    url (PatchUrlResolver.url "fix-window-role")
    sha256 "ae92602a95564efe1aecec85563b116bf4211371a7c1f7e5d9c356107b4adf6d"
  end

  #
  # Icons
  #

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

  resource "gnu-head-icon" do
    url "https://raw.githubusercontent.com/d12frosted/homebrew-emacs-plus/master/icons/heckert_gnu.icns"
    sha256 "b5899aaa3589b54c6f31aa081daf29d303047aa07b5ca1d0fd7f9333a829b6d3"
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

    if build.with? "debug"
      ENV.append "CFLAGS", "-g -Og"
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
    if build.with?("imagemagick@6") || build.with?("imagemagick@7")
      args << "--with-imagemagick"
    else
      args << "--without-imagemagick"
    end

    # Emacs 27.x (current HEAD) supports imagemagick7 but not Emacs 26.x
    if build.with? "imagemagick@7"
      imagemagick_lib_path =  Formula["imagemagick@7"].opt_lib/"pkgconfig"
      unless build.head?
        odie "--with-imagemagick@7 is supported only on --HEAD"
      end
      ohai "ImageMagick PKG_CONFIG_PATH: ", imagemagick_lib_path
      ENV.prepend_path "PKG_CONFIG_PATH", imagemagick_lib_path
    elsif build.with? "imagemagick@6"
      imagemagick_lib_path =  Formula["imagemagick@6"].opt_lib/"pkgconfig"
      ohai "ImageMagick PKG_CONFIG_PATH: ", imagemagick_lib_path
      ENV.prepend_path "PKG_CONFIG_PATH", imagemagick_lib_path
    end

    if build.with? "jansson"
      unless build.head?
        odie "--with-jansson is supported only on --HEAD"
      end
      args << "--with-json"
    end

    args << "--with-modules" if build.with? "modules"
    args << "--with-rsvg" if build.with? "librsvg"
    args << "--without-pop" if build.with? "mailutils"
    args << "--with-xwidgets" if build.with? "xwidgets"

    if build.head?
      ENV.prepend_path "PATH", Formula["gnu-sed"].opt_libexec/"gnubin"
      system "./autogen.sh"
    end

    if build.with? "cocoa" and build.without? "x11"
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

      system "make"
      system "make", "install"

      icons_dir = buildpath/"nextstep/Emacs.app/Contents/Resources"

      (%w[EmacsIcon1 EmacsIcon2 EmacsIcon3 EmacsIcon4
        EmacsIcon5 EmacsIcon6 EmacsIcon7 EmacsIcon8
        EmacsIcon9 emacs-card-blue-deep emacs-card-british-racing-green
        emacs-card-carmine emacs-card-green].map { |i| "emacs-icons-project-#{i}" } +
       %w[modern-icon gnu-head-icon spacemacs-icon]).each do |icon|
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
        ln -s #{prefix}/Emacs.app /Applications

      --natural-title-bar option was removed from this formula, in order to
        duplicate its effect add following line to your init.el file
        (add-to-list 'default-frame-alist '(ns-transparent-titlebar . t))
        (add-to-list 'default-frame-alist '(ns-appearance . dark))
      or:
        (add-to-list 'default-frame-alist '(ns-transparent-titlebar . t))
        (add-to-list 'default-frame-alist '(ns-appearance . light))

    EOS
  end

  test do
    assert_equal "4", shell_output("#{bin}/emacs --batch --eval=\"(print (+ 2 2))\"").strip
  end
end
