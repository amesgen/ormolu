{
  inputs = {
    haskellNix.url = "github:input-output-hk/haskell.nix";
    nixpkgs.follows = "haskellNix/nixpkgs-unstable";
    flake-utils.follows = "haskellNix/flake-utils";
    pre-commit-hooks = {
      url = "github:cachix/pre-commit-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-utils.follows = "flake-utils";
    };

    # for Ormolu Live
    ghc-wasm-meta.url = "gitlab:ghc/ghc-wasm-meta?host=gitlab.haskell.org";
    npmlock2nix = { url = "github:nix-community/npmlock2nix"; flake = false; };
    ps-tools = {
      follows = "purs-nix/ps-tools";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    purs-nix = {
      url = "github:purs-nix/purs-nix/ps-0.15";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
  outputs = inputs@{ self, nixpkgs, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          inherit (inputs.haskellNix) config;
          overlays = [ inputs.haskellNix.overlay ];
        };
        inherit (pkgs) lib haskell-nix;
        inherit (haskell-nix) haskellLib;

        defaultGHCVersion = "ghc925";
        ghcVersions = [ "ghc902" defaultGHCVersion ];
        perGHC = lib.genAttrs ghcVersions (ghcVersion:
          let
            hsPkgs = pkgs.haskell-nix.cabalProject {
              src = ./.;
              compiler-nix-name = ghcVersion;
              modules = [{
                packages.ormolu.writeHieFiles = true;
                packages.ormolu.components.exes.ormolu.preBuild =
                  lib.mkIf (self ? rev) ''export ORMOLU_REV=${self.rev}'';
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
            } // hackageTests // regionTests // fixityTests
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
        defaultGHC = perGHC.${defaultGHCVersion};

        binaries =
          let
            hsPkgs = defaultGHC.dev.hsPkgs.appendModule {
              modules = [{
                dontStrip = false;
                dontPatchELF = false;
                enableDeadCodeElimination = true;
              }];
            };
            ormoluExe = hsPkgs: hsPkgs.hsPkgs.ormolu.components.exes.ormolu;
          in
          lib.recurseIntoAttrs {
            Linux = ormoluExe hsPkgs.projectCross.musl64;
            macOS = pkgs.runCommand "ormolu-macOS"
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
            Windows = ormoluExe hsPkgs.projectCross.mingwW64;
          };

        pre-commit-check = inputs.pre-commit-hooks.lib.${system}.run {
          src = ./.;
          hooks = {
            nixpkgs-fmt.enable = true;
            deadnix.enable = true;
            purs-tidy.enable = true;
          };
          tools = { inherit (ormoluLive) purs-tidy; };
        };

        ormoluLive =
          let
            npmlock2nix = (pkgs.callPackage inputs.npmlock2nix { }).v2;
            ps-tools = inputs.ps-tools.legacyPackages.${system}.for-0_15;
            purs-nix = inputs.purs-nix { inherit system; };
            ps = purs-nix.purs {
              dependencies = [ "halogen" "ace" "profunctor-lenses" ];
              dir = ./ormolu-live;
            };
            es-opt = npmlock2nix.build {
              src = ./ormolu-live;
              installPhase = "cp -r output-es $out";
              buildCommands = lib.singleton ''
                purs-backend-es build --int-tags \
                  --corefn-dir ${ps.output { codegen = "corefn"; }}
              '';
            };
            metadata = builtins.toJSON {
              inherit (self.packages.${system}.default) version;
              inherit (self) rev;
              ghcAPIVersion =
                defaultGHC.dev.hsPkgs.ghc-lib-parser.components.library.version;
            };
            ghcWasmDeps = [
              inputs.ghc-wasm-meta.packages.${system}.default
              pkgs.haskellPackages.happy
              pkgs.haskellPackages.alex
            ];
          in
          {
            package = npmlock2nix.build {
              src = ./ormolu-live;
              installPhase = "cp -r dist $out";
              buildCommands = lib.optional (self ? rev) ''
                echo ${lib.escapeShellArg metadata} > src/meta.json
              '' ++ lib.singleton ''
                cp -r ${es-opt} output
                date > src/ormolu.wasm
                cp --remove-destination \
                  ${./extract-hackage-info/hackage-info.bin} src/hackage-info.bin
                parcel build --no-source-maps www/index.html
              '';
            };
            shell = npmlock2nix.shell {
              src = ./ormolu-live;
              buildInputs = [
                pkgs.nodejs
                pkgs.watchexec
                (ps.command { })
                ps-tools.purs-tidy
                ps-tools.purescript
              ] ++ ghcWasmDeps;
            };
            ghcWasmShell = pkgs.mkShell { packages = [ ghcWasmDeps ]; };
            inherit (ps-tools) purs-tidy;
          };
      in
      {
        packages = flake-utils.lib.flattenTree {
          inherit binaries pre-commit-check;
          default = defaultGHC.ormolu;
          ormoluLive = ormoluLive.package;
        };
        apps = {
          default = flake-utils.lib.mkApp {
            drv = defaultGHC.ormolu;
            exePath = "/bin/ormolu";
          };
          extract-hackage-info = flake-utils.lib.mkApp {
            drv = defaultGHC.extract-hackage-info;
            exePath = "/bin/extract-hackage-info";
          };
          format = flake-utils.lib.mkApp {
            drv = pkgs.writeShellApplication {
              name = "ormolu-format";
              text = builtins.readFile ./format.sh;
              runtimeInputs = [
                (defaultGHC.dev.hsPkgs.tool "cabal" "latest")
                defaultGHC.ormolu
              ];
            };
          };
        };
        devShells = {
          default = defaultGHC.dev.hsPkgs.shellFor {
            tools = {
              cabal = "latest";
              haskell-language-server = "latest";
            };
            withHoogle = false;
            exactDeps = false;
            inherit (pre-commit-check) shellHook;
          };
          ormoluLive = ormoluLive.shell;
          ghcWasm = ormoluLive.ghcWasmShell;
        };
        legacyPackages = defaultGHC // perGHC;
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
