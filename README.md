# print2svg

## Wat
An SVG printer for NixOS.

## Why
To use a gui to convert PDFs to SVGs. Existing tools (like`pdf2svg`)
are all cli apps, which is annoying in a graphical workflow. A virtual
printer is the simplest way to implement the gui with "free" rotation,
page ranges and so on.

## How
```nix
# flake.nix
inputs.print2svg.url = "git+https://robmason.co.uk/print2svg";

# NixOS module
imports = [ inputs.print2svg.nixosModules.default ];
services.print2svg.enable = true;
```

## How actually
1. Prints a PDF (via CUPS) into `/var/spool/print2svg/<user>/`
2. A systemd user unit monitors this dir and pops a "save" dialog with zenity
   when a file is dropped into the spool dir.
3. When a location is chosen in the zenity dialog, the temp PDF is converted
   to svgs using `pdf2svg`