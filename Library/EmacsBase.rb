require_relative "UrlResolver"
require_relative "Icons"

class CopyDownloadStrategy < AbstractFileDownloadStrategy
  def initialize(url, name, version, **meta)
    @cached_location = Pathname.new url
  end
end

class EmacsBase < Formula
  def self.init version
    @@urlResolver = UrlResolver.new(version, ENV["HOMEBREW_EMACS_PLUS_MODE"] || "remote")
  end

  def self.local_patch(name, sha:)
    patch do
      url (@@urlResolver.patch_url name), :using => CopyDownloadStrategy
      sha256 sha
    end
  end

  def self.inject_icon_options
    ICONS_CONFIG.each do |icon, sha|
      option "with-#{icon}-icon", "Using Emacs #{icon} icon"
      next if build.without? "#{icon}-icon"
      resource "#{icon}-icon" do
        url (@@urlResolver.icon_url icon), :using => CopyDownloadStrategy
        sha256 sha
      end
    end
  end

  def inject_path
    ohai "Injecting PATH value to Emacs.app/Contents/Info.plist"
    app = "#{prefix}/Emacs.app"
    plist = "#{app}/Contents/Info.plist"
    path_full = PATH.new(ENV['PATH'])

    if verbose?
      puts "Full PATH, including entries required for build: #{path_full}"
    end


    shared_idx = path_full.find_index { |x|
      x.end_with? "/Library/Homebrew/shims/shared"
    }
    path = PATH.new(path_full.drop(shared_idx + 1))

    puts "Patching plist at #{plist} with following PATH value:"
    path.each_entry { |x|
      puts x
    }

    system "/usr/libexec/PlistBuddy -c 'Add :LSEnvironment dict' '#{plist}'"
    system "/usr/libexec/PlistBuddy -c 'Add :LSEnvironment:PATH string' '#{plist}'"
    system "/usr/libexec/PlistBuddy -c 'Set :LSEnvironment:PATH #{path}' '#{plist}'"
    system "/usr/libexec/PlistBuddy -c 'Print :LSEnvironment' '#{plist}'"
    system "touch '#{app}'"
  end

  def expand_path
    # Expand PATH to include all dependencies and Superenv.bin as
    # dependencies can override standard tools.
    path = PATH.new()
    path.append(deps.map { |dep| dep.to_formula.libexec/"gnubin" })
    path.append(deps.map { |dep| dep.to_formula.opt_bin })
    path.append(ENV['PATH'])
    ENV['PATH'] = path.existing

    # TODO: remove this debug info
    if verbose?
      puts "PATH value was changed to:"
      path.each_entry { |x|
        puts x
      }
      system "which", "tar"
      system "which", "ls"
      system "which", "grep"
    end
  end

  def inject_protected_resources_usage_desc
    ohai "Injecting description for protected resources usage"
    app = "#{prefix}/Emacs.app"
    plist = "#{app}/Contents/Info.plist"

    system "/usr/libexec/PlistBuddy -c 'Add NSCameraUsageDescription string' '#{plist}'"
    system "/usr/libexec/PlistBuddy -c 'Set NSCameraUsageDescription Emacs requires permission to access the Camera.' '#{plist}'"
    system "touch '#{app}'"
  end
end
