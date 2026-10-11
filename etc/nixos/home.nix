{ ... }:

{
  imports = [ <home-manager/nixos> ];

  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;

  home-manager.users.leans = { ... }: {
    home.stateVersion = "26.05";

    programs.mangohud = {
      enable = true;
      settings = {
        legacy_layout = false;
        custom_text_center = "LeansGEN";
        background_alpha = 0.6;
        round_corners = 0;
        background_color = "000000";
        font_size = 24;
        text_color = "FFFFFF";
        position = "top-left";
        toggle_hud = "Shift_R+F12";
        gpu_list = false;
        table_columns = 3;

        gpu_text = "GPU";
        gpu_stats = true;
        gpu_load_change = true;
        gpu_load_value = "50,90";
        gpu_load_color = "FFFFFF,FFAA7F,CC0000";
        vram = true;
        vram_color = "AD64C1";
        gpu_core_clock = true;
        gpu_mem_clock = true;
        gpu_temp = true;
        gpu_mem_temp = true;
        gpu_power = true;
        gpu_color = "2E9762";

        cpu_text = "CPU";
        cpu_stats = true;
        cpu_load_change = true;
        cpu_load_value = "50,90";
        cpu_load_color = "FFFFFF,FFAA7F,CC0000";
        cpu_mhz = true;
        cpu_temp = true;
        cpu_power = true;
        cpu_color = "2E97CB";

        io_read = true;
        io_write = true;
        io_color = "A491D3";

        swap = true;
        ram = true;
        ram_color = "C26693";

        fps = true;
        fps_limit_method = "late";
        toggle_fps_limit = "Shift_L+F1";
        fps_limit = 144;
        resolution = true;
        vsync = 4;
        fps_color_change = true;
        fps_color = "B22222,FDFD09,39F900";
        fps_value = "72,144";

        display_server = true;
        output_folder = "/home/leans/.local/share/goverlay";
        log_duration = 30;
        log_interval = 100;
        toggle_logging = "Shift_L+F2";

        blacklist = "zenity,protonplus,lsfg-vk-ui,bazzar,gnome-calculator,pamac-manager,lact,ghb,bitwig-studio,ptyxis,yumex";
      };
    };
  };
}
