#!/usr/bin/env ruby
# frozen_string_literal: true

# Test suite for the service blocks of the emacs-plus formulas
#
# Run with: ruby tests/test_formula_service.rb

require 'minitest/autorun'

class TestFormulaService < Minitest::Test
  FORMULAS = Dir[File.expand_path('../Formula/emacs-plus@*.rb', __dir__)].sort

  def service_block(path)
    File.read(path)[/^  service do\n(.*?)^  end$/m, 1]
  end

  def test_formulas_found
    refute_empty FORMULAS
  end

  # A daemon that finds the server already taken exits with status 1 on
  # purpose; restarting it on any exit turns that into an endless loop (#1014)
  def test_service_restarts_only_on_crash
    FORMULAS.each do |path|
      block = service_block(path)
      name = File.basename(path, '.rb')
      refute_nil block, "#{name} has no service block"
      assert_match(/^\s*keep_alive crashed: true$/, block, "#{name} should restart the daemon only on crash")
    end
  end

  def test_service_logs_per_version
    FORMULAS.each do |path|
      block = service_block(path)
      name = File.basename(path, '.rb')
      assert_includes block, %(log_path var/"log/#{name}.stdout.log")
      assert_includes block, %(error_log_path var/"log/#{name}.stderr.log")
    end
  end
end
