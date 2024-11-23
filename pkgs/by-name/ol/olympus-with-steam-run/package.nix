{
  callPackage,
}:

callPackage ../olympus/package.nix { with-steam-run = true; }
