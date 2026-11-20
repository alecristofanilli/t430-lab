# Ambienti isolati: `nix develop .#<nome>` (oppure `use flake ~/t430-lab#<nome>` in un .envrc)
{ pkgs }:
{
  # Lavorare sul repo stesso
  default = pkgs.mkShell {
    packages = with pkgs; [
      nil
      nixfmt
      nvd
      git
    ];
  };

  datascience = pkgs.mkShell {
    packages = [
      (pkgs.python3.withPackages (
        ps: with ps; [
          numpy
          scipy
          pandas
          polars
          matplotlib
          seaborn
          scikit-learn
          statsmodels
          sympy
          jupyterlab
          ipykernel
        ]
      ))
    ];
  };

  julia = pkgs.mkShell { packages = [ pkgs.julia-bin ]; };

  r = pkgs.mkShell {
    packages = [
      (pkgs.rWrapper.override {
        packages = with pkgs.rPackages; [
          tidyverse
          data_table
        ];
      })
    ];
  };

  # Analisi dei risultati di lab-snapshot (grafici prima/dopo)
  bench = pkgs.mkShell {
    packages = with pkgs; [
      hyperfine
      stress-ng
      fio
      sysbench
      jq
      (python3.withPackages (
        ps: with ps; [
          pandas
          matplotlib
        ]
      ))
    ];
  };
}
