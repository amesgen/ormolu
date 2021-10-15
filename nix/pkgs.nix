let
  macdylibbundler = self: super: {
    macdylibbundler = super.macdylibbundler.override {
      version = "20210804";
      src = super.fetchFromGitHub {
        owner = "auriamg";
        repo = "macdylibbundler";
        rev = "5a6413cc4ea688ed59209b062f05aef092ee4585";
        sha256 = "1wvfycdsysji5j4g3lr1dwk3hbnai8pibhajnfya9vy219clp281";
      };
    };
  };
  sources = import ./sources.nix { };
  haskellNix = import sources.haskellNix { };
  inherit (haskellNix) nixpkgsArgs;
in
import haskellNix.sources.nixpkgs-unstable
  (nixpkgsArgs // { overlays = nixpkgsArgs.overlays ++ [ macdylibbundler ]; })
