# Analisi a basso livello: registri, firmware, EC, ACPI, DRAM, consumi per componente.
#
# Gli strumenti sono sempre installati. L'accesso diretto a /dev/mem e alla RAM dell'EC
# si sblocca solo avviando la voce di GRUB "deep": riduce la sicurezza del kernel e serve
# esclusivamente per le sessioni di analisi.
{
  config,
  pkgs,
  ...
}:
let
  kp = config.boot.kernelPackages;
in
{
  boot.kernelModules = [ "msr" ]; # rdmsr/wrmsr, turbostat

  environment.systemPackages =
    (with pkgs; [
      # CPU, MSR, consumi
      msr-tools
      cpuid
      powercap
      pcm
      spectre-meltdown-checker
      # firmware e chipset
      flashrom
      coreboot-utils # inteltool, ectool, ifdtool, intelmetool, superiotool, cbfstool...
      chipsec
      me_cleaner
      acpica-tools # acpidump, acpixtract, iasl
      dmidecode
      # bus e periferiche
      i2c-tools # decode-dimms, i2cdetect
      v4l-utils # edid-decode
      intel-gpu-tools
      # DRAM e tempo reale
      memtester
      rt-tests # cyclictest
      # analisi dei dump
      diffutils
      xxd
    ])
    ++ [
      kp.turbostat
      kp.cpupower
      kp.x86_energy_perf_policy
    ];

  specialisation.deep.configuration = {
    system.nixos.tags = [ "deep" ];
    boot.kernelParams = [ "iomem=relaxed" ]; # flashrom/inteltool/chipsec leggono MMIO via /dev/mem
    boot.kernelModules = [ "ec_sys" ]; # RAM dell'embedded controller in /sys/kernel/debug/ec/ec0/io (sola lettura)
  };
}
