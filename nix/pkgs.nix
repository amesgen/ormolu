let
  macdylibbundler = self: super: {
    macdylibbundler = super.macdylibbundler.overrideAttrs (old: {
      version = "1.0.0";
      src = super.fetchFromGitHub {
        owner = "auriamg";
        repo = "macdylibbundler";
        rev = "886b02b372e66e79ade5107aa0fdd359546c16b1";
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
