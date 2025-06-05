# This cell block is less idiomatic and is geared towards customizing our
# standardized environment by making an overlayed version of the rust toolchain
# available to our cell. This is the benefit of having some flexibility with how
# we organize our cells and cell blocks.
{ cell, inputs }:
let
  inherit (inputs) self nixpkgs rust-overlay;

  # `std` does not support global overlays, so we use `nixpkgs.extend` to make
  # a local overlay.
  # See: https://github.com/divnix/std/issues/117
  rust-toolchain = (nixpkgs.extend rust-overlay.overlays.default).rust-bin.fromRustupToolchainFile "${self}/rust-toolchain.toml";
in
{
  rust = rust-toolchain // {
    cargo = rust-toolchain;
    rustc = rust-toolchain;
    clippy = rust-toolchain;
    rustfmt = rust-toolchain;
  };
}
