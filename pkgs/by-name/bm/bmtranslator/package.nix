{
  lib,
  fetchFromGitHub,
  buildGoModule,
  fetchurl,
}:

let
  pname = "bmtranslator";
  # v0.2.1 build fails due to go.mod not including indirect dependencies
  version = "0.2.1-unstable-2022-01-23";
in
buildGoModule {
  inherit pname version;

  src = fetchFromGitHub {
    owner = "sxturndev";
    repo = "bmtranslator";
    rev = "5c30a5d03f33f4f1e408fda21f25a6052f26aaa3"; # tag = "v${version}";
    hash = "sha256-SZmATAh/9JRbJLG2wfNiNuSd1VLV2N6HjV5bX0PONM8=";
  };

  patches = [
    # Fix runtime error about dir execution permissions on unix systems
    (fetchurl {
      url = "https://github.com/sxturndev/bmtranslator/commit/34aeeb2237df021b6a57dc0c740a73db24921421.patch";
      hash = "sha256-ctqCjlD3e1HsyYgkmMFjodniY5wa0Bji6oW+GV01NfI=";
    })
  ];

  vendorHash = "sha256-pWHq70Skub4m6/7zdggenyQBHbkWVYEDlx3g+Jxra/k=";

  meta = with lib; {
    description = "Converts BMS levels to a modern file format (osu, qua or json) (sxturndev fork)";
    maintainers = with maintainers; [ ulysseszhan ];
    license = licenses.mit;
    homepage = "https://github.com/sxturndev/bmtranslator";
    mainProgram = "bmtranslator";
  };
}
