{
  runTest,
  zeronet,
}:
let
  port = 43110;
in
runTest (
  { lib, ... }:
  {
    name = "zeronet";
    meta = with lib.maintainers; {
      maintainers = [ fgaz ];
    };

    nodes.machine =
      { ... }:
      {
        services.zeronet = {
          enable = true;
          package = zeronet;
          inherit port;
        };
      };

    testScript = ''
      machine.wait_for_unit("zeronet.service")

      machine.wait_for_open_port(${toString port})

      machine.succeed("curl --fail -H 'Accept: text/html, application/xml, */*' localhost:${toString port}/Stats")
    '';
  }
)
