#!/usr/bin/env ruby
# frozen_string_literal: true

# Test suite for .github/scripts/update_cask_sha.py
#
# The release job rewrites one sha256 per published artifact. It used to
# require the sha256 stanza to sit on the line directly above the url, and
# brew style then moved on_intel below on_arm and put a blank line between
# the two stanzas, so Intel shas silently stopped being updated while the
# url kept pointing at the newest release.
#
# Run with: ruby tests/test_update_cask_sha.rb

require 'minitest/autorun'
require 'tmpdir'

class TestUpdateCaskSha < Minitest::Test
  SCRIPT = File.expand_path('../.github/scripts/update_cask_sha.py', __dir__)
  OLD = ('a' * 64)
  NEW = ('b' * 64)
  OTHER = ('c' * 64)

  def run_script(contents, sha, pattern)
    Dir.mktmpdir('cask-sha') do |dir|
      cask = File.join(dir, 'test.rb')
      File.write(cask, contents)
      ok = system('python3', SCRIPT, cask, sha, pattern, out: File::NULL)
      return [ok, File.read(cask)]
    end
  end

  # brew style leaves a blank line between the sha256 and url stanzas
  def test_updates_sha_separated_from_url_by_blank_line
    cask = <<~RUBY
      on_intel do
        sha256 "#{OLD}"

        url "\#{base_url}/emacs-plus-\#{emacs_ver}-x86_64-15.zip",
            verified: "github.com/d12frosted/homebrew-emacs-plus"
      end
    RUBY

    ok, result = run_script(cask, NEW, 'x86_64-15.zip')

    assert ok, 'script should succeed'
    assert_includes result, NEW
    refute_includes result, OLD
  end

  # the arm stanzas keep sha256 and url adjacent
  def test_updates_sha_directly_above_url
    cask = <<~RUBY
      on_arm do
        sha256 "#{OLD}"
        url "\#{base_url}/emacs-plus-\#{emacs_ver}-arm64-26.zip",
            verified: "github.com/d12frosted/homebrew-emacs-plus"
      end
    RUBY

    ok, result = run_script(cask, NEW, 'arm64-26.zip')

    assert ok, 'script should succeed'
    assert_includes result, NEW
  end

  # each url has its own sha256, so only the matching one may change
  def test_leaves_other_platform_shas_alone
    cask = <<~RUBY
      on_arm do
        sha256 "#{OTHER}"
        url "\#{base_url}/emacs-plus-\#{emacs_ver}-arm64-26.zip",
            verified: "github.com/d12frosted/homebrew-emacs-plus"
      end
      on_intel do
        sha256 "#{OLD}"

        url "\#{base_url}/emacs-plus-\#{emacs_ver}-x86_64-15.zip",
            verified: "github.com/d12frosted/homebrew-emacs-plus"
      end
    RUBY

    ok, result = run_script(cask, NEW, 'x86_64-15.zip')

    assert ok, 'script should succeed'
    assert_includes result, OTHER
    assert_includes result, NEW
    refute_includes result, OLD
  end

  # walking backwards must stop at the enclosing block, not borrow the sha256
  # belonging to an earlier url
  def test_fails_when_url_has_no_sha_of_its_own
    cask = <<~RUBY
      on_arm do
        sha256 "#{OTHER}"
        url "\#{base_url}/emacs-plus-\#{emacs_ver}-arm64-26.zip",
            verified: "github.com/d12frosted/homebrew-emacs-plus"
      end
      on_intel do
        url "\#{base_url}/emacs-plus-\#{emacs_ver}-x86_64-15.zip",
            verified: "github.com/d12frosted/homebrew-emacs-plus"
      end
    RUBY

    ok, result = run_script(cask, NEW, 'x86_64-15.zip')

    refute ok, 'script should fail rather than update an unrelated sha'
    assert_includes result, OTHER
    refute_includes result, NEW
  end

  # a pattern that is not in the cask is a release/cask mismatch, not a no-op
  def test_fails_when_pattern_is_absent
    cask = <<~RUBY
      on_arm do
        sha256 "#{OLD}"
        url "\#{base_url}/emacs-plus-\#{emacs_ver}-arm64-26.zip",
            verified: "github.com/d12frosted/homebrew-emacs-plus"
      end
    RUBY

    ok, result = run_script(cask, NEW, 'x86_64-15.zip')

    refute ok, 'script should fail on a pattern it cannot find'
    assert_includes result, OLD
  end
end
