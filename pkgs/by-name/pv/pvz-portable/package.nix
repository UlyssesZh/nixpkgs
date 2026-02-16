{
  lib,
  stdenv,
  fetchFromGitHub,
  cmake,
  ninja,
  unzip,
  libogg,
  libjpeg,
  libopenmpt,
  libpng,
  libvorbis,
  libmpg123,
  SDL2,
  python3,
  imagemagick,
  nix-update-script,
  # set it to a dir or a zip containing main.pak and properties; can be a path or a derivation
  # example: ./Plants_vs._Zombies_1.2.0.1073_EN.zip
  # https://github.com/wszqkzqk/PvZ-Portable/blob/main/archlinux/README.md#prepare-game-assets
  gameAssets ? null,
  pvzDebug ? false, # cheat keys and other debug features
  limboPage ? true, # access to limbo page with hidden minigame levels
  doFixBugs ? false, # fix bugs (which are usually considered features)
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "pvz-portable";
  version = "0.1.12";

  src = fetchFromGitHub {
    owner = "wszqkzqk";
    repo = "PvZ-Portable";
    tag = finalAttrs.version;
    hash = "sha256-obX+fIbt509YGesLRD9hLK+T6K1BqVOVKltXF1bZssQ=";
  };

  nativeBuildInputs = [
    cmake
    ninja
    imagemagick
  ]
  ++ lib.optional (gameAssets != null) unzip;

  buildInputs = [
    libogg
    libjpeg
    libopenmpt
    libpng
    libvorbis
    libmpg123
    SDL2
    (python3.withPackages (ps: [ ps.pyyaml ]))
  ];

  cmakeFlags = [
    (lib.cmakeBool "PVZ_DEBUG" pvzDebug)
    (lib.cmakeBool "LIMBO_PAGE" limboPage)
    (lib.cmakeBool "DO_FIX_BUGS" doFixBugs)
  ];

  installPhase = ''
    runHook preInstall

    install -Dm755 pvz-portable $out/share/pvz-portable/pvz-portable
    install -Dm755 $src/archlinux/pvz-portable.sh $out/bin/pvz-portable
    install -Dm755 $src/scripts/pvzp-v4-converter.py $out/bin/pvzp-v4-converter
    install -Dm644 $src/LICENSE $out/share/licenses/pvz-portable/LICENSE
    install -Dm644 $src/COPYING $out/share/licenses/pvz-portable/COPYING

    install -Dm664 $src/archlinux/io.github.wszqkzqk.pvz-portable.desktop $out/share/applications/io.github.wszqkzqk.pvz-portable.desktop
    install -Dm644 $src/icon.png $out/share/icons/hicolor/512x512/apps/io.github.wszqkzqk.pvz-portable.png
    for size in 16 32 48 64 128 256; do
      mkdir -p $out/share/icons/hicolor/''${size}x$size/apps
      magick $src/icon.png -resize ''${size}x$size $out/share/icons/hicolor/''${size}x$size/apps/io.github.wszqkzqk.pvz-portable.png
    done

    runHook postInstall
  '';

  postInstall = lib.optionalString (gameAssets != null) ''
    if [ -f "${gameAssets}" ]; then
      unzip "${gameAssets}" main.pak "properties/*" -d $out/share/pvz-portable
    else
      cp -r "${gameAssets}"/{main.pak,properties} $out/share/pvz-portable
    fi
  '';

  postFixup = ''
    substituteInPlace $out/bin/pvz-portable --replace-fail /usr/share/pvz-portable $out/share/pvz-portable
    substituteInPlace $out/share/applications/io.github.wszqkzqk.pvz-portable.desktop --replace-fail /usr/bin/ ""
  '';

  passthru.updateScript = nix-update-script { };

  meta = {
    description = "Cross-platform community-driven reimplementation of Plants vs. Zombies GOTY";
    homepage = "https://github.com/wszqkzqk/PvZ-Portable";
    changelog = "https://github.com/wszqkzqk/PvZ-Portable/releases";
    downloadPage = "https://github.com/wszqkzqk/PvZ-Portable/releases/tag/${finalAttrs.src.tag}";
    license = with lib.licenses; [
      lgpl3Plus
      unfreeRedistributable # PopCap Games Framework License
    ];
    maintainers = with lib.maintainers; [ ulysseszhan ];
    platforms = lib.platforms.all;
    mainProgram = "pvz-portable";
  };
})
