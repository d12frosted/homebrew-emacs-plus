class UrlResolver
  def initialize(version, mode)
    @version = version
    @formula_name = "emacs-plus@#{version}"
    @formula_dir = mode == "local" ? Dir.pwd : (UrlResolver.formula_root @formula_name)
  end

  def self.formula_root name
    begin
      Formula[@formula_name].path.to_s.delete_suffix "/Formula/#@formula_name.rb"
    rescue
      Dir.pwd
    end
  end

  def patch_url name
    "#@formula_dir/patches/emacs-#@version/#{name}.patch"
  end

  def icon_url name
    "#@formula_dir/icons/#{name}.icns"
  end
end
