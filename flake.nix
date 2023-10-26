{
  description = "Flake for development workflows.";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    rain.url = "github:rainprotocol/rain.cli";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, rain, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        rain-cli = "${rain.defaultPackage.${system}}/bin/rain";

      in rec {
        devShells.default = import ./shell.nix { inherit pkgs; };

        packages = rec {
#               ipfs-add = pkgs.writeShellScriptBin "ipfs-add" ''
#     ipfs add -r --pin --cid-version 1 erc1155Metadata
#   '';

        #   build-dispair-meta-cmd = ''
        #     ${rain-cli} meta build \
        #       -i <(${rain-cli} meta solc artifact -c abi -i out/RainterpreterExpressionDeployerNP.sol/RainterpreterExpressionDeployerNP.json) -m solidity-abi-v2 -t json -e deflate -l en \
        #       -i <(forge script --silent ./script/GetAuthoringMeta.sol && cat ./meta/AuthoringMeta.rain.meta) -m authoring-meta-v1 -t cbor -e deflate -l none \
        #   '';

        #   output-dispair-meta = pkgs.writeShellScriptBin "output-dispair-meta" ''
        #     ${(build-dispair-meta-cmd)} -o meta/RainterpreterExpressionDeployerNP.rain.meta;
        #   '';

        #   build-meta = pkgs.writeShellScriptBin "build-meta" ''
        #   set -x;

        #   ${(build-dispair-meta-cmd)} -o meta/RainterpreterExpressionDeployerNP.rain.meta;
        #   '';

        #   deploy-dispair = pkgs.writeShellScriptBin "deploy-dispair" (''
        #     set -euo pipefail;
        #     forge build --force;
        #     forge script -vvvvv script/DeployDISPair.sol --legacy --verify --broadcast --rpc-url "''${CI_DEPLOY_RPC_URL}" --etherscan-api-key "''${EXPLORER_VERIFICATION_KEY}" \
        #       --sig='run(bytes)' \
        #       "$( ${(build-dispair-meta-cmd)} -E hex )" \
        #     ;
        #   '');

        #   default = build-meta;
        };
      }
    );
}