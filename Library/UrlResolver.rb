class UrlResolver
  def self.repo
    (ENV["HOMEBREW_GITHUB_ACTOR"] or "d12frosted") + "/" + "homebrew-emacs-plus"
  end

  def self.branch
    ref = ENV["HOMEBREW_GITHUB_REF"]
    if ref
      ref.sub("refs/heads/", "")
    else
      "master"
    end
  end

  def self.patch_url(name)
    "https://raw.githubusercontent.com/#{repo}/#{branch}/patches/#{name}.patch"
  end
end
