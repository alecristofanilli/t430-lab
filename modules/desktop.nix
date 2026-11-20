{ pkgs, ... }:
{
  # Sway: tiling su Wayland, leggero, gira bene sulla Intel HD 4000.
  programs.sway = {
    enable = true;
    wrapperFeatures.gtk = true;
    extraPackages = with pkgs; [
      foot
      fuzzel
      waybar
      mako
      swaylock
      swayidle
      grim
      slurp
      wl-clipboard
      brightnessctl
      kanshi
      pulseaudio # pactl, usato dai tasti del volume nel config di default
      wmenu # menu di default di sway (Super+D è comunque rilegato a fuzzel qui sotto)
    ];
  };

  # Il config di default di sway include /etc/sway/config.d/*
  environment.etc."sway/config.d/10-t430.conf".text = ''
    input type:keyboard {
      xkb_layout it
    }
    input type:pointer {
      accel_profile flat
    }
    input type:touchpad {
      tap enabled
      natural_scroll disabled
      dwt enabled
    }
    # Le variabili del config di default sono già espanse quando questo file viene letto:
    # per cambiare terminale e menu bisogna rilegare i tasti.
    bindsym $mod+Return exec foot
    bindsym $mod+d exec fuzzel
  '';

  services.greetd = {
    enable = true;
    settings.default_session.command = "${pkgs.tuigreet}/bin/tuigreet --time --remember --cmd sway";
  };

  # Grafica Ivy Bridge: VA-API col driver i965 (decodifica video in hardware)
  hardware.graphics = {
    enable = true;
    extraPackages = [ pkgs.intel-vaapi-driver ];
  };
  environment.sessionVariables.LIBVA_DRIVER_NAME = "i965";

  # Audio
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    pulse.enable = true;
  };

  hardware.bluetooth.enable = true;

  xdg.portal = {
    enable = true;
    wlr.enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
  };

  fonts.packages = with pkgs; [
    noto-fonts
    noto-fonts-color-emoji
    nerd-fonts.jetbrains-mono
  ];

  programs.firefox.enable = true;
}
