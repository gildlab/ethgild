let
  pkgs = import
    (builtins.fetchTarball {
      name = "nixos-unstable-2022-12-18";
      url = "https://github.com/nixos/nixpkgs/archive/5c4da4dbba967c43b846bca65b6e879fbf9fde83.tar.gz";
      sha256 = "sha256:1lbkw6152a3ibjpy3qakpfgrldqzyddxyfmxxgq45pvizfk6xdd1";
    })
    { };

  ci-lint = pkgs.writeShellScriptBin "ci-lint" ''
    solhint 'contracts/**/*.sol'
    prettier --check .
  '';

  flush-all = pkgs.writeShellScriptBin "flush-all" ''
    rm -rf artifacts
    rm -rf cache
    rm -rf node_modules
    rm -rf typechain
    rm -rf typechain-types
    rm -rf bin
  '';

  security-check = pkgs.writeShellScriptBin "security-check" ''
    flush-all
    npm install

    # Run slither against all our contracts.
    # Disable npx as nix-shell already handles availability of what we need.
    # Dependencies and tests are out of scope.
    slither . --npx-disable --filter-paths="contracts/test" --exclude-dependencies --fail-high
  '';

  ipfs-add = pkgs.writeShellScriptBin "ipfs-add" ''
    ipfs add -r --pin --cid-version 1 erc1155Metadata
  '';
in
pkgs.stdenv.mkDerivation {
  name = "shell";
  buildInputs = [
    pkgs.nodejs-18_x
    pkgs.slither-analyzer
    security-check
    flush-all
    ci-lint
    ipfs-add
  ];

  shellHook = ''
    touch .env && source .env
    export PATH=$( npm bin ):$PATH
    # keep it fresh
    npm install
  '';
}