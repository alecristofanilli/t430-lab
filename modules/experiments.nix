# Ogni specialisation è una voce in più nel menu di GRUB: lo stesso sistema con una
# variabile cambiata. Avvii, lanci `lab-snapshot <nome>`, confronti con `lab-compare`.
#
#   default   → configurazione principale (tuning attivo, scheduler EEVDF del kernel)
#   vanilla   → gruppo di controllo: niente tuning, niente TLP
#   perf      → mitigazioni CPU disattivate + scheduler sched_ext scx_lavd
#   battery   → massimo risparmio energetico
#
# ATTENZIONE su "perf": mitigations=off riapre Spectre/Meltdown & co. Ha senso solo come
# esperimento su una macchina di test, per misurare quanto costano davvero le mitigazioni.
{ lib, ... }:
{
  specialisation = {
    vanilla.configuration = {
      system.nixos.tags = [ "vanilla" ];
      lab.tuning.enable = false;
      services.tlp.enable = lib.mkForce false;
      services.thinkfan.enable = lib.mkForce false;
      services.power-profiles-daemon.enable = lib.mkForce true;
    };

    perf.configuration = {
      system.nixos.tags = [ "perf" ];
      boot.kernelParams = [ "mitigations=off" ];
      services.scx-loader = {
        enable = true;
        config.default_sched = "scx_lavd";
      };
      services.tlp.settings = {
        CPU_SCALING_GOVERNOR_ON_BAT = lib.mkForce "performance";
        CPU_BOOST_ON_BAT = lib.mkForce 1;
      };
    };

    battery.configuration = {
      system.nixos.tags = [ "battery" ];
      boot.kernelParams = [
        "i915.enable_fbc=1" # framebuffer compression: meno accessi alla RAM per lo schermo
        "pcie_aspm=force"
        "workqueue.power_efficient=1"
      ];
      services.tlp.settings = {
        CPU_SCALING_GOVERNOR_ON_AC = lib.mkForce "powersave";
        CPU_ENERGY_PERF_POLICY_ON_AC = lib.mkForce "power";
        CPU_BOOST_ON_AC = lib.mkForce 0;
        CPU_MAX_PERF_ON_BAT = 70;
        RUNTIME_PM_ON_AC = lib.mkForce "auto";
      };
    };
  };
}
