let
  macdylibbundler = self: super: {
    macdylibbundler = super.macdylibbundler.overrideAttrs (old: rec {
      version = "1.0.0";
      src = super.fetchFromGitHub {
        owner = "auriamg";
        repo = "macdylibbundler";
        rev = version;
        sha256 = "02w04qvaf9v8yw8bgncx5qj3jx08xdfa855isvq92q27hsb8m8hv";
      };
    });
  };
  sources = import ./sources.nix { };
  haskellNix = import sources.haskellNix { };
  inherit (haskellNix) nixpkgsArgs;
in
import haskellNix.sources.nixpkgs-unstable
  (nixpkgsArgs // { overlays = nixpkgsArgs.overlays ++ [ macdylibbundler ]; })
