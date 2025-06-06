# SPDX-FileCopyrightText: 2025 sntx <sntx@sntx.space>
# SPDX-License-Identifier: AGPL-3.0-or-later

{ cell, inputs }:
let
  inherit (inputs)
    cells
    crate2nix
    nixpkgs
    self
    std
    ;

  # use cargo and rustc from toolchains.rust
  buildRustCrateForPkgs =
    pkgs:
    pkgs.buildRustCrate.override {
      inherit (cells.repo.toolchains.rust) cargo rustc;
    };

  generatedCargoNix = crate2nix.tools.${nixpkgs.system}.generatedCargoNix {
    name = "yes-rs";
    src = std.incl self [
      "${self}/Cargo.lock"
      "${self}/Cargo.toml"
      "${self}/src"
    ];
  };

  cargoNix = import generatedCargoNix {
    inherit buildRustCrateForPkgs;
    pkgs = nixpkgs;
  };
in
{
  default = cargoNix.rootCrate.build;
}
