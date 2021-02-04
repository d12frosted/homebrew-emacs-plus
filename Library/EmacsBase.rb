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
    "cacodemon"                       => "5a8d53896f72992bc7158aaaa47665df4009be646deee39af6f8e76893568728",
    "elrumo1"                         => "f0900babe3d36b4660a4757ac1fa8abbb6e2978f4a4f2d18fa3c7ab1613e9d42",
    "elrumo2"                         => "0fbdab5172421d8235d9c53518dc294efbb207a4903b42a1e9a18212e6bae4f4",
    "emacs-card-blue-deep"            => "6bdb17418d2c620cf4132835cfa18dcc459a7df6ce51c922cece3c7782b3b0f9",
    "emacs-card-british-racing-green" => "ddf0dff6a958e3b6b74e6371f1a68c2223b21e75200be6b4ac6f0bd94b83e1a5",
    "emacs-card-carmine"              => "4d34f2f1ce397d899c2c302f2ada917badde049c36123579dd6bb99b73ebd7f9",
    "emacs-card-green"                => "f94ade7686418073f04b73937f34a1108786400527ed109af822d61b303048f7",
    "gnu-head"                        => "b5899aaa3589b54c6f31aa081daf29d303047aa07b5ca1d0fd7f9333a829b6d3",
    "modern"                          => "eb819de2380d3e473329a4a5813fa1b4912ec284146c94f28bd24fbb79f8b2c5",
    "modern-alecive-flatwoken"        => "779373dd240aa532248ac2918da3db0207afaa004f157fa790110eef2e216ccd",
    "modern-asingh4242"               => "ff37bd9447550da54d90bfe5cb2173c93799d4c4d64f5a018cc6bfe6537517e4",
    "modern-azhilin"                  => "ee803f2d7a9ddd4d73ebb0561014b60d65f96947aa33633846aa2addace7a97a",
    "modern-bananxan"                 => "d7b4396fe667e2792c8755f85455635908091b812921890c4b0076488c880afc",
    "modern-black-dragon"             => "2844b2e57f87d9bd183c572d24c8e5a5eb8ecfc238a8714d2c6e3ea51659c92a",
    "modern-black-gnu-head"           => "9ac25aaa986b53d268e94d24bb878689c290b237a7810790dead9162e6ddf54b",
    "modern-black-variant"            => "b066ee684e68519950bcca06f631a49fbd1f5a463d49114e5063b3a5f1654d0c",
    "modern-bokehlicia-captiva"       => "8534f309b72812ba99375ebe2eb1d814bd68aec8898add2896594f4eecb10238",
    "modern-cg433n"                   => "9a0b101faa6ab543337179024b41a6e9ea0ecaf837fc8b606a19c6a51d2be5dd",
    "modern-doom"                     => "39378a10b3d7e804461eec8bb9967de0cec7b8f1151150bbe2ba16f21001722b",
    "modern-doom3"                    => "02e8535317b70c0674c608ed3b8bfee4badc8d1f4a96b99d980744c185948d24",
    "modern-mzaplotnik"               => "1f77c52d3dbcdb0b869f47264ff3c2ac9f411e92ec71061a09771b7feac2ecc6",
    "modern-nuvola"                   => "c3701e25ff46116fd694bc37d8ccec7ad9ae58bb581063f0792ea3c50d84d997",
    "modern-orange"                   => "e2f5d733f97b0a92a84b5fe0bcd4239937d8cb9de440d96e298b38d052e21b43",
    "modern-paper"                    => "209f7ea9e3b04d9b152e0580642e926d7e875bd1e33242616d266dd596f74c7a",
    "modern-papirus"                  => "1ec7c6ddcec97e6182e4ffce6220796ee1cb0b5e00da40848713ce333337222b",
    "modern-pen"                      => "4fda050447a9803d38dd6fd7d35386103735aec239151714e8bf60bf9d357d3b",
    "modern-pen-3d"                   => "ece20b691c8d61bb56e3a057345c1340c6c29f58f7798bcdc929c91d64e5599b",
    "modern-pen-black"                => "c4bf4de8aaf075d82fc363afbc480a1b8855776d0b61c3fc3a75e8063d7b5c27",
    "modern-pen-lds56"                => "dd88972e2dd2d4dfd462825212967b33af3ec1cb38f2054a23db2ea657baa8a0",
    "modern-purple-flat"              => "8468f0690efe308a4fe85c66bc3ed4902f8f984cf506318d5ef5759aa20d8bc6",
    "modern-sexy-v1"                  => "1ea8515d1f6f225047be128009e53b9aa47a242e95823c07a67c6f8a26f8d820",
    "modern-sexy-v2"                  => "ecdc902435a8852d47e2c682810146e81f5ad72ee3d0c373c936eb4c1e0966e6",
    "modern-sjrmanning"               => "fc267d801432da90de5c0d2254f6de16557193b6c062ccaae30d91b3ada01ab9",
    "modern-vscode"                   => "5cfe371a1bbfd30c8c0bd9dba525a0625036a4c699996fb302cde294d35d0057",
    "modern-yellow"                   => "b7c39da6494ee20d41ec11f473dec8ebcab5406a4adbf8e74b601c2325b5eb7d",
    "retro-emacs-logo"                => "0d7100faa68c17d012fe9309f9496b8d530946c324cb7598c93a4c425326ff97",
    "retro-gnu-meditate-levitate"     => "5424582f0a4c1998aa91eb8185e1d41961cbc9605dbcea8a037c602587b14998",
    "retro-sink"                      => "be0ee790589a3e49345e1894050678eab2c75272a8d927db46e240a2466c6abc",
    "retro-sink-bw"                   => "5cd836f86c8f5e1688d6b59bea4b57c8948026a9640257a7d2ec153ea7200571",
    "spacemacs"                       => "b3db8b7cfa4bc5bce24bc4dc1ede3b752c7186c7b54c09994eab5ec4eaa48900",
  }.freeze

  def self.inject_icon_options
    ICONS_CONFIG.each do |icon, sha|
      option "with-#{icon}-icon", "Using Emacs #{icon} icon"
      next if build.without? "#{icon}-icon"
      resource "#{icon}-icon" do
        url (UrlResolver.icon_url icon)
        sha256 sha
      end
    end
  end
end
