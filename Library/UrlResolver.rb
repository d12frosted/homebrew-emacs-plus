# Use defined? to avoid redefinition warnings when file is loaded multiple times
TAP_OWNER = "d12frosted" unless defined?(TAP_OWNER)
TAP_REPO = "emacs-plus" unless defined?(TAP_REPO)

class UrlResolver
  # Repository root derived from this file's location (Library/..).
  # Do not use Dir.pwd here: since Homebrew 5.1.15 formulas are loaded
  # inside the build sandbox whose working directory is a temporary
  # directory unrelated to the checkout.
  REPO_ROOT = File.expand_path("..", __dir__) unless defined?(REPO_ROOT)

  def initialize(version, mode)
    name = "#{TAP_REPO}@#{version}"
    tap = Tap.fetch(TAP_OWNER, TAP_REPO)
    @version = version
    @formula_root =
      mode == "local" || !tap.installed? ?
        REPO_ROOT :
        (tap.path.to_s.delete_suffix "/Formula/#{name}.rb")
  end

  def patch_url name
    "#{@formula_root}/patches/emacs-#@version/#{name}.patch"
  end
end
