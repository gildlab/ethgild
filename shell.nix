let
  pkgs = import
    (builtins.fetchTarball {
      name = "nixos-unstable-2021-10-01";
      url = "https://github.com/nixos/nixpkgs/archive/fa5e153653a1b48e4a21a14b341e2e01835ba8b5.tar.gz";
      sha256 = "1yvqxrw0ila4y6mryhpf32c8ydljfmfbvijxra2dawvhcfbbm2rw";
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
    slither . --npx-disable --filter-paths="contracts/test" --exclude-dependencies
  '';

 ci-test = pkgs.writeShellScriptBin "ci-test" ''
 flush-all
 ci-lint
 hardhat test
 security-check
 '';
in
pkgs.stdenv.mkDerivation {
 name = "shell";
 buildInputs = [
  pkgs.nodejs-14_x
  pkgs.slither-analyzer
  security-check
  flush-all
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