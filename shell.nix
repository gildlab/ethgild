let
 pkgs = import <nixpkgs> {};

 ci-lint = pkgs.writeShellScriptBin "ci-lint" ''
 solhint 'contracts/**/*.sol'
 '';

 security-check = pkgs.writeShellScriptBin "security-check" ''
 rm -rf venv
 rm -rf artifacts
 rm -rf cache
 rm -rf node_modules
 npm install
 python3 -m venv venv
 source ./venv/bin/activate
 pip install slither-analyzer
 slither .
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
  ci-test
  ci-lint
 ];

 shellHook = ''
  export PATH=$( npm bin ):$PATH
  # keep it fresh
  npm install
 '';
}