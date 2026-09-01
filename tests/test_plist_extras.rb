#!/usr/bin/env ruby
# frozen_string_literal: true

# Test suite for PlistExtras, the Info.plist customizations injected into
# Emacs.app (usage descriptions for TCC privacy services, AutoFill opt-out).
#
# Run with: ruby tests/test_plist_extras.rb

require 'minitest/autorun'
require 'tmpdir'

require_relative '../Library/PlistExtras'

class TestPlistExtras < Minitest::Test
  EMPTY_PLIST = <<~PLIST
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
    <dict>
    	<key>CFBundleName</key>
    	<string>Emacs</string>
    </dict>
    </plist>
  PLIST

  def with_plist(contents = EMPTY_PLIST)
    Dir.mktmpdir do |dir|
      plist = File.join(dir, "Info.plist")
      File.write(plist, contents)
      yield plist
    end
  end

  def read_key(plist, key)
    out = `/usr/libexec/PlistBuddy -c "Print :#{key}" "#{plist}" 2>/dev/null`
    $?.success? ? out.chomp.force_encoding(Encoding::UTF_8) : nil
  end

  # ===========================================
  # Usage description data
  # ===========================================

  # Every class-based TCC service a process started from within Emacs can
  # touch. Photos, camera, microphone, contacts, calendars, reminders,
  # Bluetooth and speech recognition kill the process with SIGABRT when the
  # key is missing; location and local network only misbehave.
  EXPECTED_KEYS = %w[
    NSBluetoothAlwaysUsageDescription
    NSCalendarsUsageDescription
    NSCalendarsFullAccessUsageDescription
    NSCalendarsWriteOnlyAccessUsageDescription
    NSCameraUsageDescription
    NSContactsUsageDescription
    NSLocalNetworkUsageDescription
    NSLocationUsageDescription
    NSLocationWhenInUseUsageDescription
    NSMicrophoneUsageDescription
    NSPhotoLibraryUsageDescription
    NSPhotoLibraryAddUsageDescription
    NSRemindersUsageDescription
    NSRemindersFullAccessUsageDescription
    NSSpeechRecognitionUsageDescription
  ].freeze

  def test_declares_every_class_based_service
    assert_equal EXPECTED_KEYS.sort, PlistExtras::USAGE_DESCRIPTIONS.keys.sort
  end

  def test_descriptions_are_sentences
    PlistExtras::USAGE_DESCRIPTIONS.each do |key, description|
      assert_kind_of String, description, "#{key} must have a string description"
      refute_empty description, "#{key} must have a non-empty description"
      assert description.end_with?("."), "#{key} description must end with a period"
    end
  end

  def test_subprocess_services_speak_for_the_subprocess
    # Emacs itself never touches these frameworks: the prompt is always about
    # something the user started from within Emacs.
    PlistExtras::USAGE_DESCRIPTIONS.each do |key, description|
      next if key == "NSSpeechRecognitionUsageDescription"

      assert description.start_with?("An application in Emacs "),
             "#{key} should attribute the request to a program running in Emacs"
    end
  end

  def test_speech_recognition_keeps_upstream_wording
    # Upstream Emacs ships this key (and this string) since Emacs 31, so keep
    # it byte-identical instead of rewording it.
    assert_equal "Emacs requires permission to handle any speech recognition.",
                 PlistExtras::USAGE_DESCRIPTIONS["NSSpeechRecognitionUsageDescription"]
  end

  # ===========================================
  # set
  # ===========================================

  def test_set_adds_missing_key
    with_plist do |plist|
      assert PlistExtras.set(plist, "NSCameraUsageDescription", "string", "Say cheese.")
      assert_equal "Say cheese.", read_key(plist, "NSCameraUsageDescription")
    end
  end

  def test_set_overwrites_existing_key
    with_plist do |plist|
      PlistExtras.set(plist, "NSCameraUsageDescription", "string", "Old wording.")
      assert PlistExtras.set(plist, "NSCameraUsageDescription", "string", "New wording.")
      assert_equal "New wording.", read_key(plist, "NSCameraUsageDescription")
    end
  end

  def test_set_preserves_untouched_keys
    with_plist do |plist|
      PlistExtras.set(plist, "NSCameraUsageDescription", "string", "Say cheese.")
      assert_equal "Emacs", read_key(plist, "CFBundleName")
    end
  end

  def test_set_handles_punctuation_and_unicode
    value = "Copyright © 1989-2026 Free Software Foundation, Inc."
    with_plist do |plist|
      assert PlistExtras.set(plist, "NSHumanReadableCopyright", "string", value)
      assert_equal value, read_key(plist, "NSHumanReadableCopyright")
    end
  end

  def test_set_writes_booleans
    with_plist do |plist|
      assert PlistExtras.set(plist, "NSAutoFillRequiresTextContentTypeForOneTimeCodeOnMac", "bool", true)
      assert_equal "true", read_key(plist, "NSAutoFillRequiresTextContentTypeForOneTimeCodeOnMac")
    end
  end

  def test_set_reports_a_missing_plist_instead_of_raising
    refute PlistExtras.set("/nonexistent/Info.plist", "NSCameraUsageDescription", "string", "Say cheese.")
  end

  def test_set_reports_an_unreadable_plist_instead_of_raising
    with_plist("not a plist at all") do |plist|
      refute PlistExtras.set(plist, "NSCameraUsageDescription", "string", "Say cheese.")
    end
  end

  # ===========================================
  # set_usage_descriptions
  # ===========================================

  def test_set_usage_descriptions_declares_every_key
    with_plist do |plist|
      assert_empty PlistExtras.set_usage_descriptions(plist)
      PlistExtras::USAGE_DESCRIPTIONS.each do |key, description|
        assert_equal description, read_key(plist, key)
      end
    end
  end

  def test_set_usage_descriptions_replaces_keys_the_bundle_already_has
    # Emacs 31 and later ship NSSpeechRecognitionUsageDescription themselves.
    with_plist do |plist|
      PlistExtras.set(plist, "NSSpeechRecognitionUsageDescription", "string", "Something else.")
      assert_empty PlistExtras.set_usage_descriptions(plist)
      assert_equal PlistExtras::USAGE_DESCRIPTIONS["NSSpeechRecognitionUsageDescription"],
                   read_key(plist, "NSSpeechRecognitionUsageDescription")
    end
  end

  # ===========================================
  # usage_descriptions_current?
  # ===========================================

  def test_usage_descriptions_are_not_current_in_a_stock_bundle
    with_plist do |plist|
      refute PlistExtras.usage_descriptions_current?(plist)
    end
  end

  def test_usage_descriptions_are_current_after_declaring_them
    with_plist do |plist|
      PlistExtras.set_usage_descriptions(plist)
      assert PlistExtras.usage_descriptions_current?(plist)
    end
  end

  def test_usage_descriptions_are_not_current_when_one_is_stale
    with_plist do |plist|
      PlistExtras.set_usage_descriptions(plist)
      PlistExtras.set(plist, "NSCameraUsageDescription", "string", "Old wording.")
      refute PlistExtras.usage_descriptions_current?(plist)
    end
  end

  def test_usage_descriptions_are_not_current_without_a_plist
    refute PlistExtras.usage_descriptions_current?("/nonexistent/Info.plist")
  end

  def test_set_usage_descriptions_reports_failed_keys
    failed = PlistExtras.set_usage_descriptions("/nonexistent/Info.plist")
    assert_equal PlistExtras::USAGE_DESCRIPTIONS.keys.sort, failed.sort
  end
end
