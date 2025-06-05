# SPDX-FileCopyrightText: 2025 sntx <sntx@sntx.space>
# SPDX-License-Identifier: AGPL-3.0-or-later

{ cell, inputs }:
let
  inherit (inputs) std cells;
  inherit (inputs.std.lib) dev;
in
{
  default = dev.mkShell {
    name = "yes-rs";

    nixago = with cell.configs; [
      conform
      lefthook
      reuse
      treefmt
    ];

    imports = [
      std.std.devshellProfiles.default

      "${inputs.devshell}/extra/language/rust.nix"
      (cell.devshellProfiles.rust {
        rust-packages = cells.rust.packages;
        rust-toolchain = cell.toolchains.rust;
      })
    ];
  };
}
