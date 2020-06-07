# coding: utf-8

require_relative '../lib/PatchUrlResolver'

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

  if build.head?
    odie <<~EOS

         Emacs 27 and Emacs 28 are now separate formulas. Please use
         emacs-plus@27 or emacs-plus@28.

         $ brew install emacs-plus@27 [options]

         or

         $ brew install emacs-plus@28 [options]

      EOS
  end

  #
  # Dependencies
  #

  depends_on "pkg-config" => :build

  depends_on "gnutls"
  depends_on "librsvg"
  depends_on "little-cms2"

  # Emacs 26.x does not support ImageMagick 7:
  # Reported on 2017-03-04: https://debbugs.gnu.org/cgi/bugreport.cgi?bug=25967
  depends_on "imagemagick@6"

  #
  # Patches
  #

  patch do
    url (PatchUrlResolver.url "emacs-26/multicolor-fonts")
    sha256 "7597514585c036c01d848b1b2cc073947518522ba6710640b1c027ff47c99ca7"
  end

  patch do
    url (PatchUrlResolver.url "emacs-26/fix-window-role")
    sha256 "1f8423ea7e6e66c9ac6dd8e37b119972daa1264de00172a24a79a710efcb8130"
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

    # Note that if ./configure is passed --with-imagemagick but can't find the
    # library it does not fail but imagemagick support will not be available.
    # See: https://debbugs.gnu.org/cgi/bugreport.cgi?bug=24455
    args << "--with-imagemagick"

    imagemagick_lib_path =  Formula["imagemagick@6"].opt_lib/"pkgconfig"
    ohai "ImageMagick PKG_CONFIG_PATH: ", imagemagick_lib_path
    ENV.prepend_path "PKG_CONFIG_PATH", imagemagick_lib_path

    args << "--with-modules"
    args << "--with-rsvg"

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

    prefix.install "nextstep/Emacs.app"

    # Replace the symlink with one that avoids starting Cocoa.
    (bin/"emacs").unlink # Kill the existing symlink
    (bin/"emacs").write <<~EOS
        #!/bin/bash
        exec #{prefix}/Emacs.app/Contents/MacOS/Emacs "$@"
      EOS

    # Follow MacPorts and don't install ctags from Emacs. This allows Vim
    # and Emacs and ctags to play together without violence.
    (bin/"ctags").unlink
    (man1/"ctags.1.gz").unlink
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

      --natural-title-bar option was removed from this formula, in order to
        duplicate its effect add following line to your init.el file
        (add-to-list 'default-frame-alist '(ns-transparent-titlebar . t))
        (add-to-list 'default-frame-alist '(ns-appearance . dark))
      or:
        (add-to-list 'default-frame-alist '(ns-transparent-titlebar . t))
        (add-to-list 'default-frame-alist '(ns-appearance . light))

      IMPORTANT: Emacs 26 is currently not supported on macOS Catalina 10.15.4+.
      Please see https://github.com/d12frosted/homebrew-emacs-plus/issues/195
      for more information.

      UPDATE: If you wish to install Emacs 27 or Emacs 28, use emacs-plus@27 or
      emacs-plus@28 formula respectively.

    EOS
  end

  test do
    assert_equal "4", shell_output("#{bin}/emacs --batch --eval=\"(print (+ 2 2))\"").strip
  end
end
