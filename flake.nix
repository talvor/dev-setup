{
  description = "dev-setup: Home Manager configurations for the OSes migrated to Nix";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-flatpak.url = "github:gmodena/nix-flatpak/v0.7.0";
    nixgl = {
      url = "github:nix-community/nixGL";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      nixpkgs,
      home-manager,
      nix-flatpak,
      nixgl,
      ...
    }:
    let
      lib = nixpkgs.lib;
      mkHome = import ./nix/mk-home.nix {
        inherit
          nixpkgs
          home-manager
          nix-flatpak
          nixgl
          ;
      };

      # OS ids managed by Home Manager, each with the systems its check builds
      # for. Every id here has os/<id>/home.nix, which is also what makes
      # setup.sh take the Nix path for that OS.
      oses = {
        popos = [ "x86_64-linux" ];
      };
      systems = lib.unique (lib.concatLists (lib.attrValues oses));

      # The real configurations describe the machine they are applied on, so
      # they read the environment and need --impure
      # (scripts/setup_home_manager.sh passes it).
      env =
        name:
        let
          value = builtins.getEnv name;
        in
        if value != "" then
          value
        else
          throw "${name} is not set. Apply the configuration with ./scripts/setup_home_manager.sh (or pass --impure with USER, HOME and DEV_SETUP_ROOT set).";
    in
    {
      homeConfigurations = lib.mapAttrs (
        os: _:
        mkHome {
          inherit os;
          system = builtins.currentSystem;
          username = env "USER";
          homeDirectory = env "HOME";
          root = env "DEV_SETUP_ROOT";
        }
      ) oses;

      # `nix flake check` builds every configuration for a placeholder user, so
      # evaluation and every package are verified without --impure.
      checks = lib.genAttrs systems (
        system:
        lib.mapAttrs (
          os: _:
          (mkHome {
            inherit os system;
            username = "dev";
            homeDirectory = "/home/dev";
            root = "/home/dev/dev-setup";
          }).activationPackage
        ) (lib.filterAttrs (_: osSystems: lib.elem system osSystems) oses)
      );

      # The home-manager CLI pinned by flake.lock
      packages = lib.genAttrs systems (system: {
        home-manager = home-manager.packages.${system}.home-manager;
      });
    };
}
