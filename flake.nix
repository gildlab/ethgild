{
  description = "Flake for development workflows.";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs";
    rainix.url = "github:rainprotocol/rainix";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, flake-utils, rainix, nixpkgs }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = rainix.pkgs.${system};
        rust-toolchain = rainix.rust-toolchain.${system};
      in rec {
        packages = rec {
          mkBin = (pkgs.makeRustPlatform{
            rustc = rust-toolchain;
            cargo = rust-toolchain;
          }).buildRustPackage {
            src = ./.;
            doCheck = false;
            name = "ethgild";
            cargoLock.lockFile = ./Cargo.lock;
            # allows for git deps to be resolved without the need to specify their outputHash
            cargoLock.allowBuiltinFetchGit = true;
            buildPhase = ''
              cargo build --release --bin ethgild --all-features
            '';
            installPhase = ''
              mkdir -p $out/bin
              cp target/release/ethgild $out/bin/
            '';
            buildInputs = with pkgs; [
              openssl
            ];
            nativeBuildInputs = with pkgs; [
              pkg-config
            ] ++ lib.optionals stdenv.isDarwin [
              darwin.apple_sdk.frameworks.SystemConfiguration
            ];
          };

          ci-lint = rainix.mkTask.${system} {
            name = "ci-lint";
            body = ''
              solhint 'contracts/**/*.sol'
              prettier --check .
            '';
          };
          flush-all = rainix.mkTask.${system} {
            name = "flush-all";
            body = ''
              rm -rf artifacts
              rm -rf cache
              rm -rf node_modules
              rm -rf typechain
              rm -rf typechain-types
              rm -rf bin
            '';
          };
          security-check = rainix.mkTask.${system} {
            name = "security-check";
            body = ''
              flush-all
              npm install

              # Run slither against all our contracts.
              # Disable npx as nix-shell already handles availability of what we need.
              # Dependencies and tests are out of scope.
              slither . --npx-disable --filter-paths="contracts/test" --exclude-dependencies --fail-high
            '';
          };
          ipfs-add = rainix.mkTask.${system} {
            name = "ipfs-add";
            body = ''
              ipfs add -r --pin --cid-version 1 erc1155Metadata
            '';
          };
        } // rainix.packages.${system};

        devShells.default = pkgs.mkShell {
          packages = [
            packages.ci-lint
            packages.flush-all
            packages.ipfs-add
            packages.security-check
          ];
          shellHook = rainix.devShells.${system}.default.shellHook;
          buildInputs = rainix.devShells.${system}.default.buildInputs;
          nativeBuildInputs = rainix.devShells.${system}.default.nativeBuildInputs;
        };
      }
    );
}
