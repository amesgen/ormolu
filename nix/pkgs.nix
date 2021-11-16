let
  sources = import ./sources.nix { };
  haskellNix = import sources.haskellNix { };
  inherit (haskellNix) nixpkgsArgs;
  overlays = nixpkgsArgs.overlays ++ [
    (self: super: {
      closurecompiler = super.closurecompiler.overrideAttrs (old: rec {
        version = "20211107";
        src = super.fetchurl {
          url = "https://repo1.maven.org/maven2/com/google/javascript/closure-compiler/v${version}/closure-compiler-v${version}.jar";
          sha256 = "733f00f0a1651c9d5409d9162e6f94f0a3e61463628925d3d6ef66be60ec14a6";
        };
      });
      macdylibbundler = super.macdylibbundler.overrideAttrs (old: {
        version = "20180825";
        src = super.fetchFromGitHub {
          owner = "auriamg";
          repo = "macdylibbundler";
          rev = "ce13cb585ead5237813b85e68fe530f085fc0a9e";
          sha256 = "149p3dcnap4hs3nhq5rfvr3m70rrb5hbr5xkj1h0gsfp0d7gvxnj";
        };
      });
    })
  ];
in
import haskellNix.sources.nixpkgs-unstable (nixpkgsArgs // { inherit overlays; })
