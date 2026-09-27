# Link dotfiles/<package> trees into $HOME, as GNU Stow did.
#
# The links point at the checkout (devSetup.root), not at a store copy, so the
# files stay editable in place. The store copy of dotfiles/ is only read to find
# what to link, so a new file or package must be tracked by git to be seen.
{ config, lib, ... }:
let
  cfg = config.devSetup;
  dotfiles = ../../dotfiles;

  # Directories that other programs write into too: link their entries rather
  # than the directory itself (Stow does the same once they exist).
  sharedDirs = [
    ".config"
    ".local"
    ".local/share"
  ];

  # Paths (relative to $HOME) to link for one package
  entries =
    pkg: rel:
    let
      dir = dotfiles + "/${pkg}" + lib.optionalString (rel != "") "/${rel}";
    in
    lib.concatLists (
      lib.mapAttrsToList (
        name: type:
        let
          path = if rel == "" then name else "${rel}/${name}";
        in
        if type == "directory" && lib.elem path sharedDirs then entries pkg path else [ path ]
      ) (builtins.readDir dir)
    );

  found = lib.filter (pkg: builtins.pathExists (dotfiles + "/${pkg}")) cfg.dotfiles;
  missing = lib.subtractLists found cfg.dotfiles;

  links = lib.concatMap (pkg: map (path: { inherit pkg path; }) (entries pkg "")) found;
  paths = map (link: link.path) links;
in
{
  options.devSetup = {
    root = lib.mkOption {
      type = lib.types.str;
      description = "Absolute path of the dev-setup checkout.";
    };
    dotfiles = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Packages (directories under dotfiles/) to link into the home directory.";
    };
  };

  config = {
    home.file = lib.listToAttrs (
      map (
        link:
        lib.nameValuePair link.path {
          source = config.lib.file.mkOutOfStoreSymlink "${cfg.root}/dotfiles/${link.pkg}/${link.path}";
        }
      ) links
    );

    warnings = map (
      pkg: "devSetup.dotfiles: skipping ${pkg}, dotfiles/${pkg} not found (or not tracked by git)"
    ) missing;

    assertions = [
      {
        assertion = lib.length (lib.unique paths) == lib.length paths;
        message = "devSetup.dotfiles: two packages link the same path: ${
          toString (lib.filter (p: lib.count (q: q == p) paths > 1) (lib.unique paths))
        }";
      }
    ];
  };
}
