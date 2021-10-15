let
  macdylibbundler = self: super: {
    macdylibbundler = super.macdylibbundler.overrideAttrs (old: rec {
      version = "1.0.0";
      src = builtins.fetchTarball {
        url = "https://github.com/auriamg/macdylibbundler/archive/refs/tags/${version}.tar.gz";
        sha256 = "9e2c892f0cfd7e10cef9af1127fee6c18a4c391463b9fc50574667eec4ec2c60";
      };
    });
  };
  sources = import ./sources.nix { };
  haskellNix = import sources.haskellNix { };
  inherit (haskellNix) nixpkgsArgs;
in
import haskellNix.sources.nixpkgs-unstable
  (nixpkgsArgs // { overlays = nixpkgsArgs.overlays ++ [ macdylibbundler ]; })
