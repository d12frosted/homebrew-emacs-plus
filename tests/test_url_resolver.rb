#!/usr/bin/env ruby
# frozen_string_literal: true

# Test suite for UrlResolver formula root resolution
#
# Run with: ruby tests/test_url_resolver.rb

require 'minitest/autorun'
require 'tmpdir'

# Mock Homebrew's Tap for testing without Homebrew
class Tap
  class << self
    attr_accessor :mock_installed, :mock_path

    def fetch(_owner, _repo)
      new
    end
  end

  def installed?
    self.class.mock_installed
  end

  def path
    self.class.mock_path
  end
end

require_relative '../Library/UrlResolver'

class TestUrlResolver < Minitest::Test
  REPO_ROOT = File.expand_path('..', __dir__)

  # Construct a resolver from inside an unrelated temporary directory to
  # simulate Homebrew's sandboxed build, which loads the formula with a
  # working directory that has nothing to do with the repository checkout.
  def resolver_from_sandbox(version, mode)
    Dir.mktmpdir('homebrew-sandbox') do |tmpdir|
      Dir.chdir(tmpdir) { return UrlResolver.new(version, mode) }
    end
  end

  def test_patch_url_uses_repo_root_when_tap_not_installed
    Tap.mock_installed = false
    resolver = resolver_from_sandbox(30, 'remote')
    assert_equal "#{REPO_ROOT}/patches/emacs-30/fix-window-role.patch",
                 resolver.patch_url('fix-window-role')
  end

  def test_patch_url_uses_repo_root_in_local_mode
    Tap.mock_installed = true
    Tap.mock_path = '/opt/homebrew/Library/Taps/d12frosted/homebrew-emacs-plus'
    resolver = resolver_from_sandbox(31, 'local')
    assert_equal "#{REPO_ROOT}/patches/emacs-31/fix-window-role.patch",
                 resolver.patch_url('fix-window-role')
  end

  def test_patch_url_uses_tap_path_when_tap_installed
    Tap.mock_installed = true
    Tap.mock_path = '/opt/homebrew/Library/Taps/d12frosted/homebrew-emacs-plus'
    resolver = resolver_from_sandbox(30, 'remote')
    assert_equal '/opt/homebrew/Library/Taps/d12frosted/homebrew-emacs-plus/patches/emacs-30/fix-window-role.patch',
                 resolver.patch_url('fix-window-role')
  end
end
