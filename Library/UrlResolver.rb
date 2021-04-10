class UrlResolver
  def initialize(version, mode)
    @version = version
    @formula_name = "emacs-plus@#{version}"
    @formula_dir =
      mode == "local" ?
        Dir.pwd :
        (Formula[@formula_name].path.to_s.delete_suffix "/Formula/#@formula_name.rb")
  end

  def patch_url name
    "#@formula_dir/patches/emacs-#@version/#{name}.patch"
  end

  def icon_url name
    "#@formula_dir/icons/#{name}.icns"
  end
end
