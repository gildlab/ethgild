let
 pkgs = import <nixpkgs> {};

 ci-lint = pkgs.writeShellScriptBin "ci-lint" ''
 solhint 'contracts/**/*.sol'
 '';

 local-node = pkgs.writeShellScriptBin "local-node" ''
 hardhat node --fork https://eth-mainnet.alchemyapi.io/v2/''${ALCHEMY_API_KEY} --fork-block-number 12619915
 '';

 local-test = pkgs.writeShellScriptBin "local-test" ''
 hardhat test --network localhost
 '';

 security-check = pkgs.writeShellScriptBin "security-check" ''
 rm -rf artifacts
 rm -rf cache
 rm -rf node_modules
 npm install
 export tmpdir=$(mktemp -d)
 python3 -m venv ''${tmpdir}/venv
 source ''${tmpdir}/venv/bin/activate
 pip install slither-analyzer
 slither . --npx-disable
 '';

 ci-test = pkgs.writeShellScriptBin "ci-test" ''
 hardhat test
 '';
in
pkgs.stdenv.mkDerivation {
 name = "shell";
 buildInputs = [
  pkgs.nodejs-14_x
  pkgs.python3
  security-check
  local-node
  local-test
  ci-test
  ci-lint
 ];

 shellHook = ''
  source .env
  export PATH=$( npm bin ):$PATH
  # keep it fresh
  npm install
 '';
}