{
  description = "A very basic flake for Rust development";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    rust-overlay.url = "github:oxalica/rust-overlay";
    crate2nix = {
      url = "github:nix-community/crate2nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    devshell = {
      url = "github:numtide/devshell";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixago = {
      url = "github:nix-community/nixago";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    std = {
      url = "github:divnix/std";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.devshell.follows = "devshell";
      inputs.nixago.follows = "nixago";
    };
  };

  outputs =
    { self, std, ... }@inputs:
    std.growOn
      {
        inherit inputs;
        cellsFrom = ./.nix;
        cellBlocks = with std.blockTypes; [
          (installables "packages")
          # Contribution Environment
          (devshells "devshells")
          (functions "configs")
          (functions "devshellProfiles")
          (functions "toolchains")
        ];
      }
      {
        devShells = std.harvest self [
          "repo"
          "devshells"
        ];
        packages = std.harvest self [
          "rust"
          "packages"
        ];
      };

  nixConfig = {
    allow-import-from-derivation = true;
  };
}
