require_relative "../Library/EmacsBase"

class EmacsPlusAT26 < EmacsBase
  init 26
  url "https://ftpmirror.gnu.org/emacs/emacs-26.3.tar.xz"
  mirror "https://ftp.gnu.org/gnu/emacs/emacs-26.3.tar.xz"
  sha256 "4d90e6751ad8967822c6e092db07466b9d383ef1653feb2f95c93e7de66d3485"

  desc "GNU Emacs text editor"
  homepage "https://www.gnu.org/software/emacs/"

  #
  # Dependencies
  #

  depends_on "pkg-config" => :build

  depends_on "gnutls"
  # Emacs 26.x does not support ImageMagick 7:
  # Reported on 2017-03-04: https://debbugs.gnu.org/cgi/bugreport.cgi?bug=25967
  depends_on "imagemagick@6"
  depends_on "librsvg"
  depends_on "little-cms2"

  #
  # Icons
  #

  inject_icon_options

  #
  # Patches
  #

  local_patch "multicolor-fonts", sha: "7597514585c036c01d848b1b2cc073947518522ba6710640b1c027ff47c99ca7"
  local_patch "fix-window-role", sha: "1f8423ea7e6e66c9ac6dd8e37b119972daa1264de00172a24a79a710efcb8130"
  local_patch "fix-unexec", sha: "a1fcfe8020301733a3846cf85b072b461b66e26d15b0154b978afb7a4ec3346b"

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

    # Note that if ./configure is passed --with-imagemagick but can't find the
    # library it does not fail but imagemagick support will not be available.
    # See: https://debbugs.gnu.org/cgi/bugreport.cgi?bug=24455
    args << "--with-imagemagick"

    imagemagick_lib_path = Formula["imagemagick@6"].opt_lib/"pkgconfig"
    ohai "ImageMagick PKG_CONFIG_PATH: ", imagemagick_lib_path
    ENV.prepend_path "PKG_CONFIG_PATH", imagemagick_lib_path
    ENV.append "CFLAGS", "-O2 -DFD_SETSIZE=10000 -DDARWIN_UNLIMITED_SELECT"

    args << "--with-modules"
    args << "--with-rsvg"

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

    # Follow MacPorts and don't install ctags from Emacs. This allows Vim
    # and Emacs and ctags to play together without violence.
    (bin/"ctags").unlink
    (man1/"ctags.1.gz").unlink
  end

  def caveats
    <<~EOS
      Emacs.app was installed to:
        #{prefix}

      To link the application to default Homebrew App location:
        osascript -e 'tell application "Finder" to make alias file to posix file "#{prefix}/Emacs.app" at posix file "/Applications" with properties {name:"Emacs.app"}'
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
