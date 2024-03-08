TAP_OWNER = "d12frosted"
TAP_REPO = "emacs-plus"

class UrlResolver
  def initialize(version, mode)
    name = "#{TAP_REPO}@#{version}"
    tap = Tap.fetch(TAP_OWNER, TAP_REPO)
    @version = version
    @formula_root =
      mode == "local" || !tap.installed? ?
        Dir.pwd :
        (tap.path.to_s.delete_suffix "/Formula/#{name}.rb")
  end

  def patch_url name
    "#{@formula_root}/patches/emacs-#@version/#{name}.patch"
  end

  def icon_url name
    "#{@formula_root}/icons/#{name}.icns"
  end
end
