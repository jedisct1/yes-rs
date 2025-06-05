{ cell, inputs }:
let
  l = nixpkgs.lib // builtins;
  nixpkgs = inputs.nixpkgs;

  # collectDependenciesForPkg :: Package —> [ Package ]
  collectDependenciesForPkg =
    pkg:
    (l.lists.unique (
      pkg.buildInputs
      ++ pkg.nativeBuildInputs
      ++ (l.flatten (l.map (dep: collectDependenciesForPkg dep) pkg.dependencies))
    ));

  # collectDependencies :: { ${pname} :: Package } -> [ Package ]
  collectDependencies =
    pkgs:
    l.lists.unique (l.flatten (l.mapAttrsToList (_: value: collectDependenciesForPkg value) pkgs));
in
{
  rust =
    {
      # this should be your rust trust-toolchain as provided by
      # - fenix
      # - rust-overlay
      # - ...
      rust-toolchain ? {
        cargo = nixpkgs.cargo;
        clippy = nixpkgs.clippy;
        rustc = nixpkgs.rustc;
        rustfmt = nixpkgs.rustfmt;
      },

      # this should be your flakes packages.${system};
      rust-packages ? {
        default = {
          buildInputs = [ ];
          dependencies = [ ];
        };
      },
    }:
    { config, ... }:
    {
      config = {
        language = {
          rust.packageSet = rust-toolchain;
        };

        packages = (collectDependencies rust-packages) ++ [ nixpkgs.pkg-config ];

        env = [
          {
            # ensures subcommands are picked up from the right place
            # but also needs to be writable; see link-cargo-home below
            name = "CARGO_HOME";
            eval = "$PRJ_DATA_DIR/cargo";
          }
          {
            name = "CARGO_TARGET_DIR";
            eval = "$PRJ_CACHE_HOME/target";
          }
          {
            # ensure we know where rustup_home will be
            name = "RUSTUP_HOME";
            eval = "$PRJ_DATA_DIR/rustup";
          }
          {
            name = "RUST_SRC_PATH";
            # accessing via toolchain doesn't fail if it's not there
            # and rust-analyzer is graceful if it's not set correctly:
            # https://github.com/rust-lang/rust-analyzer/blob/7f1234492e3164f9688027278df7e915bc1d919c/crates/project-model/src/sysroot.rs#L196-L211
            value = "${rust-toolchain}/lib/rustlib/src/rust/library";
          }
          {
            name = "PKG_CONFIG_PATH";
            value = l.makeSearchPath "lib/pkgconfig" (collectDependencies rust-packages);
          }
          {
            name = "LD_LIBRARY_PATH";
            value = l.makeLibraryPath (collectDependencies rust-packages);
          }
        ];

        # create new cargo-home and make it writable
        devshell.startup.link-cargo-home = {
          deps = [ ];
          text = ''
            # ensure CARGO_HOME is populated
            mkdir -p "$PRJ_DATA_DIR/cargo"
            ln -snf -t "$PRJ_DATA_DIR/cargo" $(ls -d ${rust-toolchain}/*)
          '';
        };

        commands =
          [
            {
              name = "toolchain";
              help = "Print toolchain versions";
              category = "rust dev";
              command = ''
                ${rust-toolchain.cargo}/bin/cargo --version
                ${rust-toolchain.clippy}/bin/cargo-clippy --version
                ${rust-toolchain.rustc}/bin/rustc --version
                ${rust-toolchain.rustfmt}/bin/rustfmt --version
              '';
            }
          ]
          ++ l.map
            (name: {
              inherit name;
              package = rust-toolchain; # has all bins
              category = "rust dev";
              help = nixpkgs.${name}.meta.description;
            })
            [
              "rustc"
              "cargo"
              "rustfmt"
              "rust-analyzer"
            ];
      };
    };
}
