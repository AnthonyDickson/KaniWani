{
  description = "Gleam Dev Environment";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
  };

  outputs =
    { nixpkgs, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in
      {
        devShells.default =
          with pkgs;
          mkShell {
            packages = with pkgs; [
              gleam
              beam28Packages.erlang
              rebar3 # required for Lustre
              dprint # For formatting markdown
              gnumake
              watchexec
            ];

            SECRET_KEY_BASE = "AVERYSECRETSECRET";
            HOST = "127.0.0.1";
            PORT = "3000";
          };
      }
    );
}
