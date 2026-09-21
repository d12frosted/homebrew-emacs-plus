# frozen_string_literal: true

# FormulaPostinstallCLI - Command-line entry point for the formula post-install
#
# Homebrew's `post_install_steps` only accepts literal step calls, no Ruby,
# so the formulas run scripts/formula-postinstall (which execs this module)
# as a `run` step. It parses the arguments the step passes, provides the
# `system_command` interface FormulaPostinstall expects, and reports errors
# with a non-zero exit status so Homebrew reports the post-install as failed,
# the same way an exception in the old post_install method did.
#
# Usage:
#   formula-postinstall --prefix PATH [--opt-prefix PATH] [--version MAJOR]
#                       [--install-info] [--apply-icon] [--link-native-lisp]

require_relative 'FormulaPostinstall'

module FormulaPostinstallCLI
  class UsageError < StandardError; end

  VALUE_OPTIONS = {
    '--prefix'     => :prefix,
    '--opt-prefix' => :opt_prefix,
    '--version'    => :version,
  }.freeze

  FLAG_OPTIONS = {
    '--install-info'     => :install_info,
    '--apply-icon'       => :apply_icon,
    '--link-native-lisp' => :link_native_lisp,
  }.freeze

  USAGE = "Usage: formula-postinstall --prefix PATH [--opt-prefix PATH] [--version MAJOR] " \
          "#{FLAG_OPTIONS.keys.map { |o| "[#{o}]" }.join(' ')}"

  # Stand-in for Formula#system: a failing command aborts the post-install
  class ShellContext
    def system_command(cmd, args: [])
      return if system(cmd, *args)

      status = $?.exitstatus
      detail = status ? "exited with status #{status}" : 'could not be run'
      raise FormulaPostinstall::CommandError, "#{([cmd] + args).join(' ')} #{detail}"
    end
  end

  class << self
    def parse(argv)
      options = FLAG_OPTIONS.values.to_h { |key| [key, false] }
      args = argv.dup
      until args.empty?
        flag = args.shift
        if (key = VALUE_OPTIONS[flag])
          raise UsageError, "#{flag} needs a value" if args.empty?

          options[key] = args.shift
        elsif (key = FLAG_OPTIONS[flag])
          options[key] = true
        else
          raise UsageError, "unknown option #{flag}"
        end
      end

      raise UsageError, 'missing --prefix' unless options[:prefix]
      raise UsageError, '--apply-icon needs --version' if options[:apply_icon] && !options[:version]
      raise UsageError, '--link-native-lisp needs --opt-prefix' if options[:link_native_lisp] && !options[:opt_prefix]

      options
    end

    # Returns the process exit status
    def run(argv)
      options = parse(argv)
      FormulaPostinstall.run(ShellContext.new, **options)
      0
    rescue UsageError => e
      warn "Error: #{e.message}"
      warn USAGE
      2
    rescue BuildConfig::ConfigurationError, FormulaPostinstall::CommandError => e
      warn "Error: #{e.message}"
      1
    end
  end
end
