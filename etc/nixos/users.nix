{ pkgs, ... }:

{
  users.users.leans = {
    isNormalUser = true;
    description = "Leans";
    extraGroups = [ "wheel" "networkmanager" "audio" "video" ];
    # Set password after install with: passwd leans
    # Or generate a hash with: mkpasswd -m sha-512
    # initialHashedPassword = "HASH_HERE";
  };
}
