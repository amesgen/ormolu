let
  macdylibbundler = self: super: {
    macdylibbundler = super.macdylibbundler.overrideAttrs (old: rec {
      version = "1.0.0";
      src = builtins.fetchTarball {
        url = "https://github.com/auriamg/macdylibbundler/archive/refs/tags/${version}.tar.gz";
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
