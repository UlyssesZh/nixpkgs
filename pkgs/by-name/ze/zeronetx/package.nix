{
  lib,
  fetchFromGitHub,
  python3Packages,
  nixosTests,
}:

python3Packages.buildPythonApplication rec {
  pname = "zeronetx";
  version = "0.9.4";
  format = "other";

  src = fetchFromGitHub {
    owner = "ZeroNetX";
    repo = "ZeroNet";
    # upstream commits are not tagged, have to manually update
    rev = "6dc1ebd93ff488dd5d8fe42242fa435a199a7833";
    hash = "sha256-pfyz7pipG0XahSmoECc6incMOnG9K7aU1NJ/QqucD68=";
  };

  propagatedBuildInputs = with python3Packages; [
    gevent
    msgpack
    base58
    merkletools
    rsa
    pysocks
    pyasn1
    websocket-client
    gevent-websocket
    rencode
    python-bitcoinlib
    maxminddb
    pyopenssl
    rich
    defusedxml
    pyaes
    coincurve
  ];

  buildPhase = ''
    runHook preBuild
    ${python3Packages.python.pythonOnBuildForHost.interpreter} -O -m compileall .
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p $out/share
    cp -r plugins src *.py $out/share/
    runHook postInstall
  '';

  postFixup = ''
    makeWrapper "$out/share/zeronet.py" "$out/bin/zeronet" \
      --set PYTHONPATH "$PYTHONPATH" \
      --set PATH ${python3Packages.python}/bin
  '';

  passthru.tests = {
    nixos-test = nixosTests.zeronetx;
  };

  meta = {
    description = "Decentralized websites using Bitcoin crypto and the BitTorrent network, fork of abandoned ZeroNet";
    mainProgram = "zeronet";
    homepage = "https://github.com/ZeroNetX/ZeroNet";
    license = lib.licenses.gpl3Only;
    maintainers = with lib.maintainers; [ ulysseszhan ];
  };
}
