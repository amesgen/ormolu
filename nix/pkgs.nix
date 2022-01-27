let
  sources = import ./sources.nix { };
  haskellNix = import sources.haskellNix { };
  inherit (haskellNix) nixpkgsArgs;
  overlays = nixpkgsArgs.overlays ++ [
    (self: super: {
      macdylibbundler = super.macdylibbundler.overrideAttrs (old: {
        version = "custom";
        src = super.fetchFromGitHub {
          owner = "amesgen";
          repo = "macdylibbundler";
          rev = "befc879d5ee812edc8f703de1a008ca0ddecf2b1";
          sha256 = "1wm4m19gc3ik79385ayy3y0jaa2alc303xjd1yskjl029q15ffa9";
        };
      });
    })
  ];
in
import haskellNix.sources.nixpkgs-unstable (nixpkgsArgs // { inherit overlays; })
