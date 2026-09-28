# Fix for nix-flatpak v0.7.0: its activation step starts the install service
# even under `home-manager switch --dry-run` (the `$DRY_RUN_CMD` only covers the
# is-system-running check). Same step, but the start goes through `run`.
{ config, lib, ... }:
let
  inherit (config.systemd.user) systemctlPath;
in
{
  config = lib.mkIf config.services.flatpak.enable {
    home.activation.flatpak-managed-install = lib.mkForce (
      lib.hm.dag.entryAfter [ "reloadSystemd" ] ''
        if ${systemctlPath} is-system-running -q; then
          run ${systemctlPath} --user start flatpak-managed-install.service || true
        fi
      ''
    );
  };
}
