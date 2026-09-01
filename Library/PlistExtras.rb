# frozen_string_literal: true

# PlistExtras - Info.plist customizations injected into Emacs.app
#
# Emacs Plus edits the Info.plist of the bundle it builds (or ships in the
# cask) before signing it. Two kinds of edits live here:
#
# 1. Usage descriptions for the class-based TCC privacy services. macOS
#    attributes a privacy check to the responsible process, which for
#    anything started from within Emacs (M-x shell, eshell, term, compile,
#    org-babel, ...) is Emacs.app itself. Without a matching key in
#    Info.plist such a process is killed with SIGABRT the moment it touches
#    the framework. Declaring a key grants nothing on its own: it only
#    carries the string macOS shows in the permission dialog, and the user
#    still answers allow or deny per service.
#
#    Upstream Emacs declines to ship these (bug#81526), and users cannot add
#    them after the fact: Info.plist is sealed by the code signature, so the
#    keys have to be in place before the bundle is signed.
#
# 2. The AutoFill opt-out, which stops macOS 26 (Tahoe) and later from
#    spawning an "AutoFill (Emacs)" helper that scans text fields for
#    one-time codes.
#
# Kept free of Homebrew dependencies so it can be unit tested directly.

require "English"

module PlistExtras
  PLIST_BUDDY = "/usr/libexec/PlistBuddy"

  # Usage descriptions for class-based TCC privacy services.
  #
  # Photos, camera, microphone, contacts, calendars, reminders, Bluetooth and
  # speech recognition are hard crashers: TCC kills the process when the key
  # is missing. Location and local network are not, but without the keys a
  # location request is silently ignored and the local network prompt shows
  # generic text, so they are declared too.
  #
  # Where Apple introduced replacement keys (calendars and reminders on macOS
  # 14), both generations are declared so older systems keep working.
  #
  # Emacs itself never uses these frameworks, so the wording attributes the
  # request to whatever the user started from within Emacs. The exception is
  # speech recognition, which upstream ships since Emacs 31 in its own voice;
  # that string is kept as upstream has it.
  USAGE_DESCRIPTIONS = {
    "NSBluetoothAlwaysUsageDescription" =>
      "An application in Emacs requires permission to use Bluetooth.",
    "NSCalendarsUsageDescription" =>
      "An application in Emacs requires permission to access your calendars.",
    "NSCalendarsFullAccessUsageDescription" =>
      "An application in Emacs requires full access to your calendars.",
    "NSCalendarsWriteOnlyAccessUsageDescription" =>
      "An application in Emacs requires permission to add events to your calendars.",
    "NSCameraUsageDescription" =>
      "An application in Emacs requires permission to use the camera.",
    "NSContactsUsageDescription" =>
      "An application in Emacs requires permission to access your contacts.",
    "NSLocalNetworkUsageDescription" =>
      "An application in Emacs requires permission to access the local network.",
    "NSLocationUsageDescription" =>
      "An application in Emacs requires permission to access your location.",
    "NSLocationWhenInUseUsageDescription" =>
      "An application in Emacs requires permission to access your location.",
    "NSMicrophoneUsageDescription" =>
      "An application in Emacs requires permission to use the microphone.",
    "NSPhotoLibraryUsageDescription" =>
      "An application in Emacs requires permission to access your photo library.",
    "NSPhotoLibraryAddUsageDescription" =>
      "An application in Emacs requires permission to add photos to your photo library.",
    "NSRemindersUsageDescription" =>
      "An application in Emacs requires permission to access your reminders.",
    "NSRemindersFullAccessUsageDescription" =>
      "An application in Emacs requires full access to your reminders.",
    "NSSpeechRecognitionUsageDescription" =>
      "Emacs requires permission to handle any speech recognition.",
  }.freeze

  class << self
    # Add a key, or set it when the bundle already declares it (Emacs 31 and
    # later ship some of these themselves). Returns true on success.
    #
    # PlistBuddy is invoked without a shell, so values may contain spaces,
    # quotes and non-ASCII characters. A failing Add is expected whenever the
    # key exists, so its output is discarded.
    #
    # The missing file is checked here because PlistBuddy still exits 0 when
    # it cannot open its destination.
    def set(plist, key, type, value)
      return false unless File.file?(plist.to_s)
      return true if run("Add :#{key} #{type} #{value}", plist, quiet: true)

      run("Set :#{key} #{value}", plist)
    end

    # Declare every usage description. Returns the keys that could not be
    # written, empty when all of them landed.
    def set_usage_descriptions(plist)
      USAGE_DESCRIPTIONS.reject { |key, description| set(plist, key, "string", description) }.keys
    end

    # Whether the bundle already declares every usage description with the
    # current wording. Lets callers skip a write (and the re-signing that
    # follows it) when there is nothing to change.
    def usage_descriptions_current?(plist)
      return false unless File.file?(plist.to_s)

      USAGE_DESCRIPTIONS.all? { |key, description| read(plist, key) == description }
    end

    # Read a string value, or nil when the key is absent.
    def read(plist, key)
      return nil unless File.file?(plist.to_s)

      output = IO.popen([PLIST_BUDDY, "-c", "Print :#{key}", plist.to_s], err: File::NULL, &:read)
      return nil unless $CHILD_STATUS.success?

      output.chomp.force_encoding(Encoding::UTF_8)
    end

    private

    def run(command, plist, quiet: false)
      options = quiet ? { out: File::NULL, err: File::NULL } : {}
      system(PLIST_BUDDY, "-c", command, plist.to_s, **options)
    end
  end
end
