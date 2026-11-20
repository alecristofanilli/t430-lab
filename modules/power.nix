# Energia e termica. Ogni valore qui è un'ipotesi di partenza da validare con `lab-snapshot`.
{ ... }:
{
  services.power-profiles-daemon.enable = false;

  services.tlp = {
    enable = true;
    settings = {
      CPU_SCALING_GOVERNOR_ON_AC = "performance";
      CPU_SCALING_GOVERNOR_ON_BAT = "powersave";
      CPU_ENERGY_PERF_POLICY_ON_AC = "balance_performance";
      CPU_ENERGY_PERF_POLICY_ON_BAT = "power";
      CPU_BOOST_ON_BAT = 0;

      # Soglie di carica per allungare la vita della batteria (da verificare: `tlp-stat -b`)
      START_CHARGE_THRESH_BAT0 = 75;
      STOP_CHARGE_THRESH_BAT0 = 90;

      RUNTIME_PM_ON_BAT = "auto";
      PCIE_ASPM_ON_BAT = "powersupersave";
      WIFI_PWR_ON_BAT = "on";
    };
  };

  services.thermald.enable = true;

  # Curva ventola personalizzata: [livello  temp_min  temp_max]
  services.thinkfan = {
    enable = true;
    levels = [
      [ 0 0 55 ]
      [ 1 50 60 ]
      [ 2 55 65 ]
      [ 3 60 70 ]
      [ 5 65 75 ]
      [ 7 70 85 ]
      [ "level auto" 80 32767 ]
    ];
  };

  services.upower.enable = true;
}
