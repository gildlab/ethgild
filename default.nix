let
  pkgs = import
    (builtins.fetchTarball {
      name = "nixos-unstable-2021-10-01";
      url = "https://github.com/nixos/nixpkgs/archive/b65120b662a663f997ddc795c3e42fe9218864c4.tar.gz";
      sha256 = "sha256:1xa1fif440zhlhc5s3pk9mkprkzvk0rcgif8k4mscbcl6c8sgqw0";
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

 ci-test = pkgs.writeShellScriptBin "ci-test" ''
 flush-all
 ci-lint
 hardhat test
 security-check
 '';

 ipfs-add = pkgs.writeShellScriptBin "ipfs-add" ''
  ipfs add -r --pin --cid-version 1 erc1155Metadata
 '';
in
pkgs.stdenv.mkDerivation {
 name = "shell";
 buildInputs = [
  pkgs.nodejs-16_x
  pkgs.slither-analyzer
  security-check
  flush-all
  ci-test
  ci-lint
  ipfs-add
  pkgs.ngrok
 ];

 shellHook = ''
  touch .env && source .env
  export PATH=$( npm bin ):$PATH
  # keep it fresh
  npm install
 '';
}