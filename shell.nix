(import ./default.nix { }).shellFor {
  tools = { cabal = "latest"; };
  withHoogle = false;
  exactDeps = true;
}
