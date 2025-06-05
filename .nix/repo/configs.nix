{ cell, inputs }:
let
  inherit (inputs) nixpkgs;
  inherit (inputs.std.data) configs;
  l = builtins // nixpkgs.lib;
in
{
  treefmt = l.attrsets.recursiveUpdate configs.treefmt {
    output = ".treefmt.toml";
    packages = with nixpkgs; [
      nixfmt-rfc-style
    ];
    commands = [
      {
        name = "treefmt";
        package = nixpkgs.treefmt;
        category = "repo tools";
      }
    ];
    data = {
      formatter = {
        nix = {
          command = l.getExe nixpkgs.nixfmt-rfc-style;
          includes = [ "*.nix" ];
        };
        shell.includes = [
          ".envrc"
          "*.sh"
        ];
        rust = {
          command = l.getExe nixpkgs.rustfmt;
          includes = [ "*.rs" ];
        };
      };
      global.excludes = [
        "*.age"
        ".gitignore"
        "*.license"
        "*.lock"
        "REUSE.toml"
        "*.txt"
      ];
    };
  };

  conform = l.attrsets.recursiveUpdate configs.conform {
    data.commit = {
      gpg.required = true;
      conventional = {
        types = [
          # Changes that affect the build system or external dependencies (example scopes: gulp, broccoli, npm)
          "build"

          # Other changes that don't modify src or test files
          "chore"

          # Changes to our Cl configuration files and scripts (example scopes: Travis, Circle, BrowserStack, SaucelLabs)
          "ci"

          # Documentation only changes
          "docs"

          # A new feature
          "feat"

          # A bug fix
          "fix"

          # A code change that improves performance
          "perf"

          # A code change that neither fixes a bug nor adds a feature
          "refactor"

          # Reverts a previous commit
          "revert"

          # Changes that do not affect the meaning of the code (white-space, formatting, missing semi-colons, etc.)
          "style"

          # Adding missing tests or correcting existing tests
          "test"
        ];
        scopes = [
          "Cargo.toml"
          "configs"
          "devshellProfiles"
          "devshells"
          "*.lock"
        ];
      };
    };
  };

  reuse = {
    format = "toml";
    hook.mode = "copy";
    output = "REUSE.toml";
    programs = with nixpkgs; [ reuse ];
    commands = [
      {
        name = "reuse";
        help = "check for compliance with the REUSE recommendations";
        package = nixpkgs.reuse;
        category = "repo tools";
      }
    ];
    data = {
      version = 1;
      annotations = [
        {
          path = [
            "Cargo.lock"
            "flake.lock"
            "REUSE.toml"
          ];
          precedence = "aggregate";
          SPDX-FileCopyrightText = "2025 sntx <sntx@sntx.space>";
          SPDX-License-Identifier = "AGPL-3.0-or-later";
        }
      ];
    };
  };

  lefthook = l.attrsets.recursiveUpdate configs.lefthook rec {
    output = ".lefthook.yaml";
    commands = [
      {
        name = "check";
        help = "check whether the flake evaluates and run its tests";
        command = data.pre-push.commands.flake-check.run;
        category = "repo tools";
      }
    ];
    data = {
      pre-commit = {
        parallel = true;
        commands = {
          reuse.run = "${l.getExe nixpkgs.reuse} lint";
        };
      };
      pre-push = {
        parallel = true;
        commands = {
          flake-check.run = l.concatStringsSep " " [
            "${l.getExe nixpkgs.nix} flake check"
            "--extra-experimental-features pipe-operators"
            "--accept-flake-config"
            "$@"
          ];
        };
      };
    };
  };
}
