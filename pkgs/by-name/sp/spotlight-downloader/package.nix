{
  lib,
  fetchFromGitHub,
  buildDotnetModule,
  dotnetCorePackages,
  makeWrapper,
  nix-update-script,
}:

buildDotnetModule (finalAttrs: {
  pname = "spotlight-downloader";
  version = "2.0.0";

  src = fetchFromGitHub {
    owner = "ORelio";
    repo = "Spotlight-Downloader";
    tag = "v${finalAttrs.version}";
    hash = "sha256-smBjoXtJGE6GVgIXb6UGz60geybi8RRzkkGX78E6YDQ=";
  };

  projectFile = "SpotlightDownloader/SpotlightDownloader.csproj";
  nugetDeps = ./deps.json;

  dotnet-sdk = dotnetCorePackages.sdk_9_0;
  dotnet-runtime = dotnetCorePackages.runtime_9_0;

  passthru.updateScript = nix-update-script { };

  meta = {
    description = "Retrieve Windows Spotlight images from the Microsoft Spotlight API";
    license = lib.licenses.cddl;
    maintainers = with lib.maintainers; [ ulysseszhan ];
    homepage = "https://github.com/ORelio/Spotlight-Downloader";
    platforms = lib.platforms.unix;
    mainProgram = "SpotlightDownloader";
  };
})
