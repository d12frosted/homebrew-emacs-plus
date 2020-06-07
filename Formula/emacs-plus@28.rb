# coding: utf-8

require_relative 'PatchUrlResolver'

class EmacsPlusAT28 < Formula
  desc "GNU Emacs text editor"
  homepage "https://www.gnu.org/software/emacs/"
  url "https://github.com/emacs-mirror/emacs.git"
  version "28.0.50"

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
  option "with-jansson", "Build with jansson support"

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

  option "with-spacemacs-icon", "Build with Spacemacs icon by Nasser Alshammari"
  option "with-modern-icon", "Using a modern style Emacs icon by @tpanum"
  option "with-gnu-head-icon", "Using a Bold GNU Head icon by Aurélio A. Heckert"
  option "with-modern-icon-cg433n", "Use a modern style icon by @cg433n"
  option "with-modern-icon-sjrmanning", "Use a modern style icon by @sjrmanning"
  option "with-modern-icon-sexy-v1", "Use a modern style icon by Emacs is Sexy (v1)"
  option "with-modern-icon-sexy-v2", "Use a modern style icon by Emacs is Sexy (v2)"
  option "with-modern-icon-papirus", "Use a modern style icon by Papirus Development Team"
  option "with-modern-icon-pen", "Use a modern style icon by Kentaro Ohkouchi"
  option "with-modern-icon-black-variant", "Use a modern style icon by BlackVariant"
  option "with-modern-icon-nuvola", "Use a modern style icon by David Vignoni (Nuvola Icon Theme)"
  option "with-retro-icon-sink-bw", "Use a retro style icon by Unknown"
  option "with-retro-icon-sink", "Use a retro style icon by Erik Mugele"
  option "with-no-frame-refocus", "Disables frame re-focus (ie. closing one frame does not refocus another one)"

  #
  # Dependencies
  #

  depends_on "autoconf" => :build
  depends_on "gnu-sed" => :build
  depends_on "texinfo" => :build
  depends_on "pkg-config" => :build
  depends_on "gnutls"
  depends_on "librsvg"
  depends_on "little-cms2"
  depends_on :x11 => :optional
  depends_on "dbus" => :optional
  depends_on "mailutils" => :optional
  depends_on "imagemagick@7" => :recommended
  depends_on "jansson" => :optional

  if build.with? "x11"
    depends_on "freetype" => :recommended
    depends_on "fontconfig" => :recommended
  end

  #
  # Incompatible options
  #

  if build.with? "xwidgets"
    unless build.with? "cocoa" and build.without? "x11"
      odie "--with-xwidgets is not available when building --with-x11"
    end
  end

  #
  # Patches
  #

  if build.with? "no-titlebar"
    patch do
      url (PatchUrlResolver.url "emacs-28/no-titlebar")
      sha256 "990af9b0e0031bd8118f53e614e6b310739a34175a1001fbafc45eeaa4488c0a"
    end
  end

  if build.with? "xwidgets"
    patch do
      url (PatchUrlResolver.url "emacs-28/xwidgets_webkit_in_cocoa")
      sha256 "c281e09b27e3672a412e9b3fe24bdad430d2f374bd4d1b0b79d667a2e6f01805"
    end
  end

  if build.with? "no-frame-refocus"
    patch do
      url (PatchUrlResolver.url "emacs-28/no-frame-refocus-cocoa")
      sha256 "fb5777dc890aa07349f143ae65c2bcf43edad6febfd564b01a2235c5a15fcabd"
    end
  end

  patch do
    url (PatchUrlResolver.url "emacs-28/fix-window-role")
    sha256 "1f8423ea7e6e66c9ac6dd8e37b119972daa1264de00172a24a79a710efcb8130"
  end

  patch do
    url (PatchUrlResolver.url "emacs-28/system-appearance")
    sha256 "2a0ce452b164eee3689ee0c58e1f47db368cb21b724cda56c33f6fe57d95e9b7"
  end

  #
  # Icons
  #

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

  resource "modern-icon" do
    url "https://s3.amazonaws.com/emacs-mac-port/Emacs.icns.modern"
    sha256 "eb819de2380d3e473329a4a5813fa1b4912ec284146c94f28bd24fbb79f8b2c5"
  end

  resource "modern-icon-cg433n" do
    url "https://raw.githubusercontent.com/d12frosted/homebrew-emacs-plus/master/icons/modern-icon-cg433n.icns"
    sha256 "9a0b101faa6ab543337179024b41a6e9ea0ecaf837fc8b606a19c6a51d2be5dd"
  end

  resource "modern-icon-sjrmanning" do
    url "https://raw.githubusercontent.com/d12frosted/homebrew-emacs-plus/master/icons/modern-icon-sjrmanning.icns"
    sha256 "fc267d801432da90de5c0d2254f6de16557193b6c062ccaae30d91b3ada01ab9"
  end

  resource "modern-icon-sexy-v1" do
    url "https://raw.githubusercontent.com/d12frosted/homebrew-emacs-plus/master/icons/modern-icon-sexy-v1.icns"
    sha256 "1ea8515d1f6f225047be128009e53b9aa47a242e95823c07a67c6f8a26f8d820"
  end

  resource "modern-icon-sexy-v2" do
    url "https://raw.githubusercontent.com/d12frosted/homebrew-emacs-plus/master/icons/modern-icon-sexy-v2.icns"
    sha256 "ecdc902435a8852d47e2c682810146e81f5ad72ee3d0c373c936eb4c1e0966e6"
  end

  resource "modern-icon-papirus" do
    url "https://raw.githubusercontent.com/d12frosted/homebrew-emacs-plus/master/icons/modern-icon-papirus.icns"
    sha256 "50aef07397ab17073deb107e32a8c7b86a0e9dddf5a0f78c4fcff796099623f8"
  end

  resource "modern-icon-pen" do
    url "https://raw.githubusercontent.com/d12frosted/homebrew-emacs-plus/master/icons/modern-icon-pen.icns"
    sha256 "4fda050447a9803d38dd6fd7d35386103735aec239151714e8bf60bf9d357d3b"
  end

  resource "modern-icon-nuvola" do
    url "https://raw.githubusercontent.com/d12frosted/homebrew-emacs-plus/master/icons/modern-icon-nuvola.icns"
    sha256 "c3701e25ff46116fd694bc37d8ccec7ad9ae58bb581063f0792ea3c50d84d997"
  end

  resource "modern-icon-black-variant" do
    url "https://raw.githubusercontent.com/d12frosted/homebrew-emacs-plus/master/icons/modern-icon-black-variant.icns"
    sha256 "a56a19fb5195925c09f38708fd6a6c58c283a1725f7998e3574b0826c6d9ac7e"
  end

  resource "retro-icon-sink-bw" do
    url "https://raw.githubusercontent.com/d12frosted/homebrew-emacs-plus/master/icons/retro-icon-sink-bw.icns"
    sha256 "5cd836f86c8f5e1688d6b59bea4b57c8948026a9640257a7d2ec153ea7200571"
  end

  resource "retro-icon-sink" do
    url "https://raw.githubusercontent.com/d12frosted/homebrew-emacs-plus/master/icons/retro-icon-sink.icns"
    sha256 "be0ee790589a3e49345e1894050678eab2c75272a8d927db46e240a2466c6abc"
  end

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

    if build.with? "debug"
      ENV.append "CFLAGS", "-g -Og"
    end

    if build.with? "dbus"
      args << "--with-dbus"
    else
      args << "--without-dbus"
    end

    # Note that if ./configure is passed --with-imagemagick but can't find the
    # library it does not fail but imagemagick support will not be available.
    # See: https://debbugs.gnu.org/cgi/bugreport.cgi?bug=24455
    if build.with?("imagemagick@7")
      args << "--with-imagemagick"
    else
      args << "--without-imagemagick"
    end

    # Emacs 27.x (current HEAD) supports imagemagick7 but not Emacs 26.x
    if build.with? "imagemagick@7"
      imagemagick_lib_path =  Formula["imagemagick@7"].opt_lib/"pkgconfig"
      ohai "ImageMagick PKG_CONFIG_PATH: ", imagemagick_lib_path
      ENV.prepend_path "PKG_CONFIG_PATH", imagemagick_lib_path
    end

    if build.with? "jansson"
      args << "--with-json"
    end

    args << "--with-modules"
    args << "--with-rsvg"
    args << "--without-pop" if build.with? "mailutils"
    args << "--with-xwidgets" if build.with? "xwidgets"

    ENV.prepend_path "PATH", Formula["gnu-sed"].opt_libexec/"gnubin"
    system "./autogen.sh"

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
       %w[modern-icon gnu-head-icon modern-icon-cg433n
        modern-icon-sjrmanning modern-icon-sexy-v1
        modern-icon-sexy-v2 modern-icon-papirus modern-icon-pen
        modern-icon-black-variant modern-icon-nuvola
        retro-icon-sink-bw retro-icon-sink spacemacs-icon]).each do |icon| next if
        build.without? icon

        rm "#{icons_dir}/Emacs.icns"
        resource(icon).stage do
          icons_dir.install Dir["*.icns*"].first => "Emacs.icns"
        end
        break
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

  def plist
    <<~EOS
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
    EOS
  end

  test do
    assert_equal "4", shell_output("#{bin}/emacs --batch --eval=\"(print (+ 2 2))\"").strip
  end
end
