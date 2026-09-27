#!/usr/bin/env ruby
# frozen_string_literal: true

# Test suite for the prebuilt cask targets
#
# Run with: ruby tests/test_cask_targets.rb
#
# The macOS versions the casks download for, the runners that build them
# and the artifacts the release jobs require must all agree, or a cask
# ends up pointing at an asset that no build produces.

require 'minitest/autorun'

class TestCaskTargets < Minitest::Test
  ROOT = File.expand_path("..", __dir__)
  CASKS = %w[emacs-plus-app emacs-plus-app@next emacs-plus-app@master].freeze
  TARGETS = %w[arm64-15 arm64-26].freeze

  def workflow
    @workflow ||= File.read("#{ROOT}/.github/workflows/build-app.yml", encoding: "UTF-8")
  end

  def cask(name)
    File.read("#{ROOT}/Casks/#{name}.rb")
  end

  def test_casks_download_only_built_targets
    CASKS.each do |name|
      targets = cask(name).scan(/emacs_ver\}-(arm64-\d+)\.zip/).flatten.sort
      assert_equal TARGETS, targets, "#{name} urls"
    end
  end

  def test_casks_require_oldest_built_macos
    # macOS 14 (Sonoma) is a tier 3 Homebrew configuration without bottles,
    # so its build compiled dependencies such as llvm from source
    CASKS.each do |name|
      assert_includes cask(name), "depends_on macos: :sequoia", name
      refute_includes cask(name), ":sonoma", name
    end
  end

  def test_workflow_builds_and_requires_same_targets
    refute_includes workflow, "runner: macos-14"
    required = workflow.scan(/for target in ([^;]+); do/).flatten.uniq
    assert_equal [TARGETS.join(" ")], required
  end
end
