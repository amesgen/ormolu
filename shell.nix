(import ./default.nix).hsPkgs.shellFor {
  tools = { cabal = "latest"; };
  withHoogle = false;
  exactDeps = true;
}
