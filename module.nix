{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.print2svg;
  package = pkgs.callPackage ./package.nix { };
  spool = "/var/spool/print2svg";
in
{
  options.services.print2svg = {
    enable = lib.mkEnableOption "a \"Print to SVG\" printer";

    users = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = lib.attrNames (lib.filterAttrs (_: u: u.isNormalUser) config.users.users);
      defaultText = lib.literalExpression "all users with isNormalUser = true";
      description = "Users who can print to SVG.";
    };
  };

  config = lib.mkIf cfg.enable {
    services.printing = {
      enable = true;
      drivers = [
        package
        pkgs.cups-filters # converts non-PDF jobs (text, images) to PDF
      ];
    };

    hardware.printers.ensurePrinters = [
      {
        name = "SVG";
        description = "Print to SVG";
        deviceUri = "print2svg:/";
        model = "print2svg.ppd";
      }
    ];

    # ensure-printers only re-runs when its script changes, which doesn't cover
    # edits to the PPD. Re-run it whenever the package changes instead.
    systemd.services.ensure-printers.restartTriggers = [ package ];

    # One private dir per user: the backend (group lp) writes jobs in, the
    # user reads and deletes them.
    systemd.tmpfiles.rules = [
      "d ${spool} 0755 root root -"
    ] ++ map (user: "d ${spool}/${user} 0770 ${user} lp -") cfg.users;

    systemd.user.paths.print2svg = {
      description = "Watch for jobs printed to SVG";
      wantedBy = [ "graphical-session.target" ];
      partOf = [ "graphical-session.target" ];
      pathConfig.PathExistsGlob = "${spool}/%u/*.pdf";
    };

    systemd.user.services.print2svg = {
      description = "Save jobs printed to SVG";
      partOf = [ "graphical-session.target" ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = lib.getExe' package "print2svg-convert";
      };
    };
  };
}
