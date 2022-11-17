{
  inputs = {
    haskellNix.url = "github:input-output-hk/haskell.nix";
    nixpkgs.follows = "haskellNix/nixpkgs-unstable";
    flake-utils.follows = "haskellNix/flake-utils";
  };
  outputs = { self, nixpkgs, flake-utils, haskellNix, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          inherit (haskellNix) config;
          overlays = [ haskellNix.overlay ];
        };
        inherit (pkgs) lib haskell-nix;
        inherit (haskell-nix) haskellLib;

        defaultGHCVersion = "ghc925";
        ghcVersions = [ "ghc8107" "ghc902" defaultGHCVersion ];
        perGHC = lib.genAttrs ghcVersions
          (ghcVersion:
            let
              hsPkgs = pkgs.haskell-nix.cabalProject {
                src = ./.;
                compiler-nix-name = ghcVersion;
                modules =
                  let
                    setRev = lib.optionalAttrs (self ? rev) {
                      preBuild = ''
                        export ORMOLU_REV=${self.rev}
                      '';
                    };
                  in
                  [{
                    packages.ormolu.writeHieFiles = true;
                    packages.ormolu.components.exes.ormolu = setRev;
                    packages.ormolu-live.components.exes.ormolu-live = setRev;
                  }];
              };
              inherit (hsPkgs.ormolu.components.exes) ormolu;
              hackageTests = import ./expected-failures { inherit pkgs ormolu; };
              regionTests = import ./region-tests { inherit pkgs ormolu; };
              fixityTests = import ./fixity-tests { inherit pkgs ormolu; };
              packages = lib.recurseIntoAttrs ({
                inherit ormolu;
                ormoluTests = haskellLib.collectChecks' hsPkgs;
                dev = { inherit hsPkgs; };
              }
              // hackageTests // regionTests // fixityTests
              // lib.optionalAttrs (ghcVersion == defaultGHCVersion) {
                inherit (hsPkgs.extract-hackage-info.components.exes) extract-hackage-info;
                weeder = pkgs.runCommand
                  "ormolu-weeder"
                  {
                    buildInputs = [ (hsPkgs.tool "weeder" "2.4.0") ];
                  } ''
                  mkdir -p $out
                  export XDG_CACHE_HOME=$TMPDIR/cache
                  weeder --config ${./weeder.dhall} \
                    --hie-directory ${hsPkgs.ormolu.components.library.hie} \
                    --hie-directory ${hsPkgs.ormolu.components.exes.ormolu.hie} \
                    --hie-directory ${hsPkgs.ormolu.components.tests.tests.hie}
                '';
              });
            in
            packages // {
              ci = pkgs.linkFarmFromDrvs "ormolu-ci-${ghcVersion}"
                (lib.attrValues (flake-utils.lib.flattenTree packages));
            });

        binaries =
          let
            hsPkgs = perGHC.${defaultGHCVersion}.dev.hsPkgs.appendModule {
              modules = [{
                dontStrip = false;
                dontPatchELF = false;
                enableDeadCodeElimination = true;
              }];
            };
            ormoluExe = hsPkgs: hsPkgs.hsPkgs.ormolu.components.exes.ormolu;
          in
          {
            "binaries/Linux" = ormoluExe hsPkgs.projectCross.musl64;
            "binaries/macOS" = pkgs.runCommand "ormolu-macOS"
              {
                nativeBuildInputs = [ pkgs.macdylibbundler ];
              } ''
              mkdir -p $out/bin
              cp ${ormoluExe hsPkgs}/bin/ormolu $out/bin/ormolu
              chmod 755 $out/bin/ormolu
              dylibbundler -b \
                -x $out/bin/ormolu \
                -d $out/bin \
                -p '@executable_path'
            '';
            "binaries/Windows" = ormoluExe hsPkgs.projectCross.mingwW64;
          };

        ormoluLive =
          let
            hsPkgs = { no-code }: perGHC.ghc8107.dev.hsPkgs.appendModule {
              modules = [
                ({ pkgs, lib, ... }: lib.mkIf pkgs.stdenv.hostPlatform.isGhcjs {
                  reinstallableLibGhc = false;
                  packages.ormolu = {
                    flags.fixity-th = false;
                    writeHieFiles = lib.mkForce false;
                  };
                  packages.ormolu-live.ghcOptions =
                    lib.optional no-code "-fno-code";
                  packages.ghc-lib-parser.patches = [
                    # see https://github.com/ghcjs/ghcjs/issues/836
                    ./nix/lexer-no-unlifted-newtypes.patch
                  ];
                })
              ];
            };
            ormoluLive = hsPkgs:
              hsPkgs.projectCross.ghcjs.hsPkgs.ormolu-live.components.exes.ormolu-live;
          in
          {
            "ormoluLive/no-code" =
              (ormoluLive (hsPkgs { no-code = true; })).overrideAttrs (_: {
                outputs = [ "out" ];
                installPhase = ''
                  mkdir -p $out
                '';
              });
            "ormoluLive/website" = pkgs.stdenv.mkDerivation {
              name = "ormolu-live-website";
              src = ./ormolu-live/www;
              buildInputs = [ pkgs.closurecompiler ];
              installPhase = ''
                cp -r . $out
                ORMOLU_LIVE=${ormoluLive (hsPkgs { no-code = false; })}/bin/ormolu-live.jsexe
                # ADVANCED/SIMPLE optimizations break semantics :(
                closure-compiler \
                  $ORMOLU_LIVE/all.js --externs $ORMOLU_LIVE/all.js.externs \
                  -O WHITESPACE_ONLY --jscomp_off=checkVars -W QUIET \
                  --js_output_file $out/all.min.js
              '';
            };
          };
      in
      {
        packages =
          flake-utils.lib.flattenTree perGHC // binaries // ormoluLive // {
            default = perGHC.${defaultGHCVersion}.ormolu;
          };
        apps = {
          default = flake-utils.lib.mkApp {
            drv = perGHC.${defaultGHCVersion}.ormolu;
            exePath = "/bin/ormolu";
          };
          extract-hackage-info = flake-utils.lib.mkApp {
            drv = perGHC.${defaultGHCVersion}.extract-hackage-info;
            exePath = "/bin/extract-hackage-info";
          };
        };
        devShells =
          let
            shellFor = ghcVersion: packages:
              perGHC.${ghcVersion}.dev.hsPkgs.shellFor {
                inherit packages;
                tools = {
                  cabal = "latest";
                  haskell-language-server = "latest";
                };
                withHoogle = false;
                exactDeps = false;
              };
          in
          {
            default = shellFor defaultGHCVersion (ps: [ ps.ormolu ]);
            ormoluLive = shellFor "ghc8107" (ps: [ ps.ormolu-live ]);
            extractHackageInfo = shellFor defaultGHCVersion (ps: [ ps.extract-hackage-info ]);
            cabalAndOrmolu = pkgs.mkShell {
              packages = [
                (perGHC.${defaultGHCVersion}.dev.hsPkgs.tool "cabal" "latest")
                self.packages.${system}.default
              ];
            };
          };
        legacyPackages = {
          inherit (perGHC.${defaultGHCVersion}) hackage;
        };
      });
  nixConfig = {
    extra-substituters = [
      "https://cache.iog.io"
    ];
    extra-trusted-public-keys = [
      "hydra.iohk.io:f/Ea+s+dFdN+3Y/G+FDgSq+a5NEWhJGzdjvKNGv0/EQ="
    ];
  };
}
