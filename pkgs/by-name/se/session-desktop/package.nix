{
  lib,
  fetchFromGitHub,
  makeDesktopItem,
  writeShellScriptBin,
  copyDesktopItems,
  stdenv,
  makeWrapper,
  fetchpatch,
  replaceVars,
  fetchYarnDeps,
  yarnConfigHook,
  yarnBuildHook,
  yarnInstallHook,
  rustPlatform,
  nodejs,
  electron,
  jq,
  tsx,
  python3,
  git,
  cmake,
  openssl,
  tcl,
  xcodebuild,
  cctools,
  darwin,
}:

let
  fake-git = writeShellScriptBin "git" (lib.readFile ./fake-git.sh);

  libsession-util-nodejs = stdenv.mkDerivation (finalAttrs: {
    pname = "libsession-util-nodejs";
    version = "0.6.9"; # find version in yarn.lock
    src = fetchFromGitHub {
      owner = "session-foundation";
      repo = "libsession-util-nodejs";
      tag = "v${finalAttrs.version}";
      fetchSubmodules = true;
      deepClone = true; # need git rev for all submodules
      hash = "sha256-Ei77Fk4KjdnIVz2w5kkHcFishd/tGxzmb0eNnFBHQwc=";
      # fetchgit is not reproducible with deepClone + fetchSubmodules:
      # https://github.com/NixOS/nixpkgs/issues/100498
      postFetch = ''
        find $out -name .git -type d -prune | while read -r gitdir; do
          pushd "$(dirname "$gitdir")"
          git rev-parse HEAD > .gitrev
          popd
        done
        find $out -name .git -type d -prune -exec rm -rf {} +
      '';
    };

    postPatch = ''
      sed -i -E 's/--runtime-version=[^[:space:]]*/--runtime-version=${electron.version}/' package.json
    '';

    nativeBuildInputs = [
      yarnConfigHook
      yarnBuildHook
      yarnInstallHook
      nodejs
      cmake
      python3
      fake-git # used in update_version.sh, libsession-util/external/oxen-libquic/cmake/check_submodule.cmake, etc.
      jq
    ];

    dontUseCmakeConfigure = true;
    yarnOfflineCache = fetchYarnDeps {
      yarnLock = "${finalAttrs.src}/yarn.lock";
      hash = "sha256-0pH88EOqxG/kg7edaWnaLEs3iqhIoRCJxDdBn4JxYeY=";
    };

    preBuild = ''
      # prevent downloading; see https://github.com/cmake-js/cmake-js/blob/v7.3.1/lib/dist.js
      mkdir -p "$HOME/.cmake-js/electron-${stdenv.hostPlatform.node.arch}"
      ln -s ${electron.headers} "$HOME/.cmake-js/electron-${stdenv.hostPlatform.node.arch}/v${electron.version}"
    '';

    # The install script is the build script.
    # `yarn install` may be better than `yarn run install`.
    # However, the former seems to use /bin/bash while the latter uses stdenv.shell,
    # and the former simply cannot find the cmake-js command, which is pretty weird,
    # and using `yarn config set script-shell` does not help.
    yarnBuildScript = "run";
    yarnBuildFlags = "install";

    postInstall = ''
      # build is not installed by default because it is in .gitignore
      cp -r build $out/lib/node_modules/libsession_util_nodejs
    '';

    meta = {
      homepage = "https://github.com/session-foundation/libsession-util-nodejs";
      # No license file, but gpl3Only makes sense because package.json says GPL-3.0,
      # which is also consistent with session-desktop and libsession-util.
      license = lib.licenses.gpl3Only;
    };
  });

in
stdenv.mkDerivation (finalAttrs: {
  pname = "session-desktop";
  version = "1.17.8";
  src =
    (fetchFromGitHub {
      owner = "session-foundation";
      repo = "session-desktop";
      tag = "v${finalAttrs.version}";
      fetchSubmodules = true;
      leaveDotGit = true;
      postFetch = ''
        pushd $out
        git rev-parse HEAD > .gitrev
        rm -rf .git
        popd
      '';
      hash = "sha256-oDD1b+s+V/EfhnPsOuckr2wZSKKd+YhV0cR98oPLtBo=";
    }).overrideAttrs
      (oldAttrs: {
        # https://github.com/NixOS/nixpkgs/issues/195117#issuecomment-1410398050
        env = oldAttrs.env or { } // {
          GIT_CONFIG_COUNT = 1;
          GIT_CONFIG_KEY_0 = "url.https://github.com/.insteadOf";
          GIT_CONFIG_VALUE_0 = "git@github.com:";
        };
      });

  postPatch = ''
    jq '
      del(.engines) # too restrictive Node version requirement
      + {files: ["app"]} # control what files are packed in the install phase
    ' package.json > package.json.new
    mv package.json.new package.json

    # use tsx from nixpkgs instead of using npx to download it
    sed -i 's|npx -y tsx|${lib.getExe tsx}|g' package.json
  '';

  nativeBuildInputs = [
    copyDesktopItems
    makeWrapper
    yarnConfigHook
    yarnBuildHook
    yarnInstallHook
    nodejs
    jq
    python3
    fake-git # see build/updateLocalConfig.js
  ]
  ++ lib.optionals stdenv.hostPlatform.isDarwin [
    cctools # provides libtool needed for better-sqlite3
    xcodebuild
    darwin.autoSignDarwinBinariesHook
  ];

  env = {
    npm_config_nodedir = electron.headers;
    ELECTRON_SKIP_BINARY_DOWNLOAD = 1;
  };

  dontUseCmakeConfigure = true;
  yarnOfflineCache = fetchYarnDeps {
    # Future maintainers: keep in mind that sometimes the upstream deduplicates dependencies
    # (see the `dedup` script in package.json) before committing yarn.lock,
    # which may unfortunately break the offline cache (and may not).
    # If that happens, clone the repo and run `yarn install --ignore-scripts` yourself,
    # copy the modified yarn.lock here, and use `./yarn.lock` instead of `"${finalAttrs.src}/yarn.lock"`,
    # and also add `cp ${./yarn.lock} yarn.lock` to postPatch.
    yarnLock = "${finalAttrs.src}/yarn.lock";
    hash = "sha256-RojQPXHyrG+df6S7+A/ev9xegvY4kpVHH6xdZHuYqxI=";
  };

  preBuild = ''
    export NODE_ENV=production

    # rebuild native modules except libsession_util_nodejs
    rm -rf node_modules/libsession_util_nodejs
    npm rebuild --verbose --offline --no-progress --release # why doesn't yarn have `rebuild`?
    cp -r ${finalAttrs.passthru.libsession-util-nodejs}/lib/node_modules/libsession_util_nodejs node_modules
    chmod -R +w node_modules/libsession_util_nodejs
    rm -rf node_modules/libsession_util_nodejs/node_modules

    # some important things that did not run because of --ignore-scripts
    yarn run postinstall
  '';

  preInstall = ''
    # Do not want yarn prune to remove native modules that we just built.
    mv node_modules node_modules.dev
  '';

  postInstall = ''
    phome="$out/lib/node_modules/session-desktop"

    find node_modules.dev -mindepth 2 -maxdepth 3 -type d -name build  | while read -r buildDir; do
      packageDir=$(dirname ''${buildDir#node_modules.dev/})
      installPackageDir="$phome/node_modules/$packageDir"
      if [ -d "$installPackageDir" ]; then
        cp -r "$buildDir" "$installPackageDir"
      fi
    done

    mv $phome/app/* $phome
    rm -r $phome/app

    makeWrapper ${lib.getExe electron} $out/bin/session-desktop \
      --add-flags $phome \
      --add-flags "\''${NIXOS_OZONE_WL:+\''${WAYLAND_DISPLAY:+--ozone-platform-hint=auto --enable-features=WaylandWindowDecorations --enable-wayland-ime=true}}" \
      --set NODE_ENV production \
      --suffix LD_LIBRARY_PATH : "${lib.makeLibraryPath [ stdenv.cc.cc ]}" \
      --inherit-argv0

    for f in build/icons/icon_*.png; do
      base=$(basename $f .png)
      size=''${base#icon_}
      install -Dm644 $f $out/share/icons/hicolor/$size/apps/session-desktop.png
    done
  ''
  + lib.optionalString stdenv.hostPlatform.isDarwin ''
    mkdir -p $out/Applications/Session.app/Contents/{MacOS,Resources}
    ln -s $out/bin/session-desktop $out/Applications/Session.app/Contents/MacOS/Session
    install -Dm644 build/icon-mac.icns $out/Applications/Session.app/Contents/Resources/icon.icns
    install -Dm644 ${
      # Adapted from the dmg package from upstream:
      # https://github.com/session-foundation/session-desktop/releases/download/v1.16.10/session-desktop-mac-arm64-1.16.10.dmg
      replaceVars ./Info.plist { inherit (finalAttrs) version; }
    } $out/Applications/Session.app/Contents/Info.plist
  '';

  desktopItems = [
    (makeDesktopItem {
      name = "Session";
      desktopName = "Session";
      comment = "Onion routing based messenger";
      exec = "session-desktop";
      icon = "session-desktop";
      terminal = false;
      type = "Application";
      categories = [ "Network" ];
    })
  ];

  passthru = {
    inherit libsession-util-nodejs;
    updateScript = ./update.sh;
  };

  meta = {
    description = "Onion routing based messenger";
    mainProgram = "session-desktop";
    homepage = "https://getsession.org/";
    downloadPage = "https://getsession.org/download";
    changelog = "https://github.com/session-foundation/session-desktop/releases/tag/${finalAttrs.src.tag}";
    license = lib.licenses.gpl3Only;
    maintainers = with lib.maintainers; [
      alexnortung
      ulysseszhan
    ];
    platforms = lib.platforms.all;
  };
})
