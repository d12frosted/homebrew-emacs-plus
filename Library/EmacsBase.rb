require_relative "UrlResolver"

class EmacsBase < Formula
  desc "GNU Emacs text editor"
  homepage "https://www.gnu.org/software/emacs/"

  ICONS_CONFIG = {
    "EmacsIcon1"                      => "50dbaf2f6d67d7050d63d987fe3743156b44556ab42e6d9eee92248c56011bd0",
    "EmacsIcon2"                      => "8d63589b0302a67f13ab94b91683a8ad7c2b9e880eabe008056a246a22592963",
    "EmacsIcon3"                      => "80dd2a4776739a081e0a42008e8444c729d41ba876b19fa9d33fde98ee3e0ebf",
    "EmacsIcon4"                      => "8ce646ca895abe7f45029f8ff8f5eac7ab76713203e246b70dea1b8a21a6c135",
    "EmacsIcon5"                      => "ca415df7ad60b0dc495626b0593d3e975b5f24397ad0f3d802455c3f8a3bd778",
    "EmacsIcon6"                      => "12a1999eb006abac11535b7fe4299ebb3c8e468360faf074eb8f0e5dec1ac6b0",
    "EmacsIcon7"                      => "f5067132ea12b253fb4a3ea924c75352af28793dcf40b3063bea01af9b2bd78c",
    "EmacsIcon8"                      => "d330b15cec1bcdfb8a1e8f8913d8680f5328d59486596fc0a9439b54eba340a0",
    "EmacsIcon9"                      => "f58f46e5ef109fff8adb963a97aea4d1b99ca09265597f07ee95bf9d1ed4472e",
    "emacs-card-blue-deep"            => "6bdb17418d2c620cf4132835cfa18dcc459a7df6ce51c922cece3c7782b3b0f9",
    "emacs-card-british-racing-green" => "ddf0dff6a958e3b6b74e6371f1a68c2223b21e75200be6b4ac6f0bd94b83e1a5",
    "emacs-card-carmine"              => "4d34f2f1ce397d899c2c302f2ada917badde049c36123579dd6bb99b73ebd7f9",
    "emacs-card-green"                => "f94ade7686418073f04b73937f34a1108786400527ed109af822d61b303048f7",
    "spacemacs"                       => "b3db8b7cfa4bc5bce24bc4dc1ede3b752c7186c7b54c09994eab5ec4eaa48900",
    "gnu-head"                        => "b5899aaa3589b54c6f31aa081daf29d303047aa07b5ca1d0fd7f9333a829b6d3",
    "retro-sink-bw"                   => "5cd836f86c8f5e1688d6b59bea4b57c8948026a9640257a7d2ec153ea7200571",
    "retro-sink"                      => "be0ee790589a3e49345e1894050678eab2c75272a8d927db46e240a2466c6abc",
    "modern"                          => "eb819de2380d3e473329a4a5813fa1b4912ec284146c94f28bd24fbb79f8b2c5",
    "modern-cg433n"                   => "9a0b101faa6ab543337179024b41a6e9ea0ecaf837fc8b606a19c6a51d2be5dd",
    "modern-sjrmanning"               => "fc267d801432da90de5c0d2254f6de16557193b6c062ccaae30d91b3ada01ab9",
    "modern-sexy-v1"                  => "1ea8515d1f6f225047be128009e53b9aa47a242e95823c07a67c6f8a26f8d820",
    "modern-sexy-v2"                  => "ecdc902435a8852d47e2c682810146e81f5ad72ee3d0c373c936eb4c1e0966e6",
    "modern-papirus"                  => "50aef07397ab17073deb107e32a8c7b86a0e9dddf5a0f78c4fcff796099623f8",
    "modern-pen"                      => "4fda050447a9803d38dd6fd7d35386103735aec239151714e8bf60bf9d357d3b",
    "modern-black-variant"            => "a56a19fb5195925c09f38708fd6a6c58c283a1725f7998e3574b0826c6d9ac7e",
    "modern-nuvola"                   => "c3701e25ff46116fd694bc37d8ccec7ad9ae58bb581063f0792ea3c50d84d997",
  }.freeze

  def self.inject_icon_options
    ICONS_CONFIG.each do |icon, sha|
      option "with-#{icon}-icon", "Using Emacs #{icon} icon"
      resource "#{icon}-icon" do
        url (UrlResolver.icon_url icon)
        sha256 sha
      end
    end
  end
end
