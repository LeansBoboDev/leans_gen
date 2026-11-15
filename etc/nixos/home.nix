{ ... }:

{
  imports = [ <home-manager/nixos> ];

  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;
  home-manager.backupFileExtension = "backup";

  home-manager.users.leans = { ... }: {
    home.stateVersion = "26.05";

    programs.mangohud.enable = true;

    # NOTE: o arquivo e escrito literalmente (e nao via programs.mangohud.settings)
    # porque o home-manager renderiza o attrset com mapAttrsToList, que ordena as
    # chaves alfabeticamente. Com legacy_layout=0 o MangoHud desenha os elementos
    # na ordem em que aparecem no arquivo, entao a ordem precisa ser explicita.
    xdg.configFile."MangoHud/MangoHud.conf".text = ''
      ### Aparencia / comportamento (nao gera linha no HUD, ordem irrelevante)
      legacy_layout=0
      table_columns=3
      position=top-left
      font_size=24
      text_color=FFFFFF
      background_color=000000
      background_alpha=0.6
      round_corners=0
      gpu_list=0
      vsync=4

      toggle_hud=Shift_R+F12
      toggle_fps_limit=Shift_L+F1
      toggle_logging=Shift_L+F2
      fps_limit=144
      fps_limit_method=late

      output_folder=/home/leans/.local/share/goverlay
      log_duration=30
      log_interval=100

      blacklist=zenity,protonplus,lsfg-vk-ui,bazzar,gnome-calculator,pamac-manager,lact,ghb,bitwig-studio,ptyxis,yumex

      ### Cores e limiares dos blocos
      cpu_text=CPU
      cpu_color=2E97CB
      cpu_load_change
      cpu_load_value=50,90
      cpu_load_color=FFFFFF,FFAA7F,CC0000

      gpu_text=GPU
      gpu_color=2E9762
      gpu_load_change
      gpu_load_value=50,90
      gpu_load_color=FFFFFF,FFAA7F,CC0000

      vram_color=AD64C1
      ram_color=C26693
      io_color=A491D3

      fps_color_change
      fps_color=B22222,FDFD09,39F900
      fps_value=72,144

      ###############################################
      ### ORDEM DO HUD - cada linha abaixo e um bloco
      ###############################################

      # 1. Texto central
      custom_text_center=LeansGEN

      # 2. Display server
      display_server

      # 3. Resolucao
      resolution

      # 4. CPU
      cpu_stats
      cpu_mhz
      cpu_temp
      cpu_power

      # 5. GPU
      gpu_stats
      gpu_core_clock
      gpu_temp
      gpu_power

      # 6. VRAM
      vram
      gpu_mem_clock
      gpu_mem_temp

      # 7. RAM
      ram
      swap

      # 8. IO RW
      io_read
      io_write

      # 9. DXVK / FPS
      fps
    '';
  };
}
