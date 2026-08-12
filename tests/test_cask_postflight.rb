#!/usr/bin/env ruby
# frozen_string_literal: true

# Test suite for CaskPostflight shared cask postflight logic
#
# Run with: ruby tests/test_cask_postflight.rb

require 'minitest/autorun'
require 'minitest/mock'
require 'tmpdir'
require 'fileutils'

# Mock Hardware::CPU for testing without Homebrew (CaskEnv depends on it)
module Hardware
  module CPU
    class << self
      attr_accessor :mock_arm

      def arm?
        @mock_arm.nil? ? false : @mock_arm
      end
    end
  end
end

require_relative '../Library/CaskPostflight'

# Records system_command invocations the way a cask postflight block would
class FakeContext
  Command = Struct.new(:cmd, :args, :sudo, keyword_init: true)

  attr_reader :commands

  def initialize
    @commands = []
  end

  def system_command(cmd, args:, sudo: false)
    @commands << Command.new(cmd: cmd, args: args, sudo: sudo)
  end
end

class TestCaskPostflight < Minitest::Test
  def setup
    Hardware::CPU.mock_arm = true
    @tmpdir = Dir.mktmpdir
    @emacs_app = File.join(@tmpdir, 'Emacs.app')
    @client_app = File.join(@tmpdir, 'Emacs Client.app')
    @prefix = File.join(@tmpdir, 'prefix')
    FileUtils.mkdir_p(File.join(@emacs_app, 'Contents/MacOS/bin'))
    FileUtils.mkdir_p(@client_app)
    FileUtils.mkdir_p(File.join(@prefix, 'bin'))
    @ctx = FakeContext.new
  end

  def teardown
    FileUtils.remove_entry(@tmpdir)
  end

  def run_postflight(inject: false, icon: false)
    inject_args = nil
    icon_args = nil
    CaskEnv.stub(:inject, lambda { |*args|
      inject_args = args
      inject
    }) do
      IconApplier.stub(:apply, lambda { |*args, **kwargs|
        icon_args = [args, kwargs]
        icon
      }) do
        CaskPostflight.run(@ctx,
                           emacs_app: @emacs_app,
                           emacs_client_app: @client_app,
                           version: '31',
                           homebrew_prefix: @prefix)
      end
    end
    { inject_args: inject_args, icon_args: icon_args }
  end

  def commands_for(cmd)
    @ctx.commands.select { |c| c.cmd == cmd }
  end

  # ===========================================
  # Quarantine removal
  # ===========================================

  def test_removes_quarantine_from_both_apps
    run_postflight
    xattr = commands_for('/usr/bin/xattr')
    assert_equal 2, xattr.size
    assert_equal ['-r', '-d', 'com.apple.quarantine', @emacs_app], xattr[0].args
    assert_equal ['-r', '-d', 'com.apple.quarantine', @client_app], xattr[1].args
    xattr.each { |c| refute c.sudo }
  end

  # ===========================================
  # Env injection and icon application
  # ===========================================

  def test_passes_app_paths_to_cask_env
    result = run_postflight
    assert_equal [@emacs_app, @client_app], result[:inject_args]
  end

  def test_passes_app_paths_and_version_to_icon_applier
    result = run_postflight
    args, kwargs = result[:icon_args]
    assert_equal [@emacs_app, @client_app], args
    assert_equal({ version: '31' }, kwargs)
  end

  def test_applies_icon_even_when_env_injection_modified_bundles
    result = run_postflight(inject: true, icon: false)
    refute_nil result[:icon_args]
  end

  # ===========================================
  # Re-signing
  # ===========================================

  def test_no_resign_when_bundles_untouched
    run_postflight(inject: false, icon: false)
    assert_empty commands_for('/usr/bin/codesign')
  end

  def test_resigns_both_apps_after_env_injection
    run_postflight(inject: true, icon: false)
    codesign = commands_for('/usr/bin/codesign')
    assert_equal 2, codesign.size
    assert_equal ['--force', '--deep', '--sign', '-', @emacs_app], codesign[0].args
    assert_equal ['--force', '--deep', '--sign', '-', @client_app], codesign[1].args
  end

  def test_resigns_both_apps_after_icon_application
    run_postflight(inject: false, icon: true)
    assert_equal 2, commands_for('/usr/bin/codesign').size
  end

  # ===========================================
  # emacs symlink
  # ===========================================

  def wrapper_path
    File.join(@emacs_app, 'Contents/MacOS/bin/emacs')
  end

  def symlink_path
    File.join(@prefix, 'bin/emacs')
  end

  def test_creates_emacs_symlink_when_wrapper_exists
    FileUtils.touch(wrapper_path)
    run_postflight
    assert File.symlink?(symlink_path)
    assert_equal wrapper_path, File.readlink(symlink_path)
  end

  def test_keeps_existing_emacs_symlink
    FileUtils.touch(wrapper_path)
    other_target = File.join(@tmpdir, 'other-emacs')
    FileUtils.touch(other_target)
    File.symlink(other_target, symlink_path)
    run_postflight
    assert_equal other_target, File.readlink(symlink_path)
  end

  def test_no_symlink_when_wrapper_missing
    run_postflight
    refute File.exist?(symlink_path)
    refute File.symlink?(symlink_path)
  end
end
