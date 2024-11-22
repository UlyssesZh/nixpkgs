{
  lib,
  fetchFromGitHub,
  fetchzip,
  buildDotnetModule,
  mono,
  love,
  luajitPackages,
  msbuild,
  sqlite,
  curl,
  libarchive,
  buildFHSEnv,
  xdg-utils,
}:
# WONTFIX: On NixOS, cannot launch Steam installations of Everest / Celeste from Olympus.
# The way it launches Celeste is by directly executing steamapps/common/Celeste/Celeste,
# and it does not work on NixOS (even with steam-run).
# This should be considered a bug of Steam on NixOS (and is probably very hard to fix).
# https://github.com/EverestAPI/Olympus/issues/94 could be a temporary fix

# FIXME: olympus checks if xdg-mime x-scheme-handler/everest for a popup. If it's not set it complains about it.
# I'm pretty sure thats by user so end user needs to do it

let
  luaPackages = luajitPackages;
  lua-subprocess = luaPackages.buildLuarocksPackage {
    pname = "subprocess";
    version = "bfa8e9";
    src = fetchFromGitHub {
      owner = "0x0ade"; # a developer of Everest
      repo = "lua-subprocess";
      rev = "bfa8e97da774141f301cfd1106dca53a30a4de54";
      hash = "sha256-4LiYWB3PAQ/s33Yj/gwC+Ef1vGe5FedWexeCBVSDIV0=";
    };
    rockspecFilename = "subprocess-scm-1.rockspec";
  };
  lsqlite3 = luaPackages.buildLuarocksPackage {
    pname = "lsqlite3";
    version = "0.9.6-1";
    src = fetchzip {
      url = "http://lua.sqlite.org/index.cgi/zip/lsqlite3_v096.zip";
      hash = "sha256-Mq409A3X9/OS7IPI/KlULR6ZihqnYKk/mS/W/2yrGBg=";
    };
    buildInputs = [ sqlite.dev ];
  };
  nfd = luaPackages.nfd;

  # NOTE: on installation olympus uses MiniInstallerLinux which is dynamically linked, this makes it run fine
  fhs-env = buildFHSEnv {
    name = "olympus-fhs";
    targetPkgs =
      pkgs:
      (with pkgs; [
        icu
        stdenv.cc.cc
        libgcc.lib
        openssl
        dotnet-runtime
      ]);
    runScript = "bash";
  };

  pname = "olympus";
  version = "24.10.27.01";
  phome = "$out/lib/${pname}";
in
buildDotnetModule {
  inherit pname version;

  src = fetchFromGitHub {
    owner = "EverestAPI";
    repo = "Olympus";
    rev = "3ab5d063bb3eef815dbf6bb76e0d225af5f814be";
    fetchSubmodules = true; # Required. See upstream's README.
    hash = "sha256-7H5rO2PG19xS+FE/4ZkvuObReASWlaMVhAd4Ou9oDrs=";
  };

  nativeBuildInputs = [
    libarchive # To create the .love file (zip format)
  ];

  buildInputs = [
    love
    mono
    nfd
    lua-subprocess
    lsqlite3
  ];

  runtimeInputs = [
    xdg-utils # used by Olympus to check installation completeness
  ];

  nugetDeps = ./deps.nix;
  projectFile = "sharp/Olympus.Sharp.csproj";
  executables = [ ];

  preConfigure = ''
    echo ${version} > src/version.txt
  '';

  # Hack Olympus.Sharp.bin.{x86,x86_64} to use system mono.
  # This was proposed by @0x0ade on discord.gg/celeste:
  # https://discord.com/channels/403698615446536203/514006912115802113/827507533962149900
  postBuild = ''
    dotnet_out=sharp/bin/Release/net452
    dotnet_out=$dotnet_out/$(ls $dotnet_out)
    makeWrapper ${lib.getExe mono} $dotnet_out/Olympus.Sharp.bin.x86 \
      --add-flags ${phome}/sharp/Olympus.Sharp.exe
    cp $dotnet_out/Olympus.Sharp.bin.x86 $dotnet_out/Olympus.Sharp.bin.x86_64
  '';

  # The script find-love is hacked to use love from nixpkgs.
  # It is used to launch Loenn from Olympus.
  # I assume --fused is so saves are properly made (https://love2d.org/wiki/love.filesystem)
  installPhase =
    let
      subprocess-cpath = "${lua-subprocess}/lib/lua/5.1/?.so";
      nfd-cpath = "${nfd}/lib/lua/5.1/?.so";
      lsqlite3-cpath = "${lsqlite3}/lib/lua/5.1/?.so";
    in
    ''
      runHook preInstall

      mkdir -p $out/bin
      makeWrapper ${lib.getExe love} ${phome}/find-love \
        --add-flags "--fused"
      makeWrapper ${phome}/find-love $out/bin/olympus \
        --prefix LUA_CPATH : "${nfd-cpath};${subprocess-cpath};${lsqlite3-cpath}" \
        --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath [ curl ]} \
        --add-flags "${phome}/olympus.love"
      mkdir -p ${phome}
      bsdtar --format zip --strip-components 1 -cf ${phome}/olympus.love src

      dotnet_out=sharp/bin/Release/net452
      dotnet_out=$dotnet_out/$(ls $dotnet_out)
      install -Dm755 $dotnet_out/* -t ${phome}/sharp

      runHook postInstall
    '';

  # we need to force olympus to use the fhs-env
  postInstall = ''
    sed -i 's|^exec|& ${fhs-env}/bin/olympus-fhs|' $out/bin/olympus
    install -Dm644 lib-linux/olympus.desktop $out/share/applications/olympus.desktop
    install -Dm644 src/data/icon.png $out/share/icons/hicolor/128x128/apps/olympus.png
    install -Dm644 LICENSE $out/share/licenses/${pname}/LICENSE
  '';

  passthru.updateScript = ./update.sh;

  meta = {
    description = "Cross-platform GUI Everest installer and Celeste mod manager";
    homepage = "https://github.com/EverestAPI/Olympus";
    changelog = "https://github.com/EverestAPI/Olympus/blob/main/changelog.txt";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [
      ulysseszhan
      petingoso
    ];
    mainProgram = "olympus";
    platforms = lib.platforms.unix;
    sourceProvenance = with lib.sourceTypes; [
      fromSource
      binaryNativeCode # Source contains binary; see https://github.com/EverestAPI/Olympus/tree/main/lib-linux/sharp
    ];
  };
}
