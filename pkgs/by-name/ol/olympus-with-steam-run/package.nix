{
  steam-run,
  callPackage,
}:

callPackage ../olympus/package.nix { celesteWrapper = steam-run; }
