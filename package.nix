{
  lib,
  stdenvNoCC,
  replaceVars,
  writeShellApplication,
  coreutils,
  gawk,
  pdf2svg,
  poppler-utils,
  qpdf,
  zenity,
}:
let
  convert = writeShellApplication {
    name = "print2svg-convert";
    runtimeInputs = [
      coreutils
      gawk
      pdf2svg
      poppler-utils
      zenity
    ];
    text = builtins.readFile ./convert.sh;
  };
in
stdenvNoCC.mkDerivation {
  pname = "print2svg";
  version = "0.1.0";
  dontUnpack = true;

  installPhase = ''
    install -Dm555 ${
      replaceVars ./backend.sh {
        path = lib.makeBinPath [
          coreutils
          qpdf
        ];
      }
    } $out/lib/cups/backend/print2svg
    install -Dm444 ${./print2svg.ppd} $out/share/cups/model/print2svg.ppd
    install -Dm555 ${lib.getExe convert} $out/bin/print2svg-convert
  '';

  meta = {
    description = "CUPS printer that saves print jobs as SVG";
    platforms = lib.platforms.linux;
  };
}
