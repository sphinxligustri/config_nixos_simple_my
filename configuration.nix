{
  config,
  lib,
  pkgs,
  ...
}:
let {
    USER_NAME = "";
    HOST_NAME = "";
    LUKS_ENC_DEVICE = "";
    HOST_ID = "";
    TAILSCALE_AUTH_KEY = "";
} in
{
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    <home-manager/nixos>
  ];

  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nixpkgs.config.allowUnfree = true;

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  # luks setup
  boot.initrd.luks.devices.luksCrypted.device = LUKS_ENC_DEVICE; # eg: /dev/sda2
  boot.initrd.luks.devices.luksCrypted.allowDiscards = true; # Allow TRIM commands for SSDs

  boot.supportedFilesystems = [ "ntfs" "ext4" "zfs" ];
  boot.zfs.forceImportRoot = false;

  networking.hostName = HOST_NAME; # Define your hostname.
  networking.hostId = HOST_ID;

  # Pick only one of the below networking options.
  networking.networkmanager.enable = true; # Easiest to use and most distros use this by default.

  # Set your time zone.
  # time.timeZone = "Europe/Berlin";
  services.tzupdate.enable = true;

  # Select internationalisation properties.
  # i18n.defaultLocale = "en_US.UTF-8";
  console = {
    font = "Lat2-Terminus16";
    useXkbConfig = true; # use xkb.options in tty.
  };

  # Set XKB keyboard layout options
  services.xserver.xkb = {
    layout = "no"; # Set the keyboard layout to US    
    options = "eurosign:e,caps:escape";
  };

  # Enable the KDE Plasma desktop environment
  services.desktopManager.plasma6.enable = true;

  # Enable the SDDM display manager
  services.displayManager.sddm.enable = true;
  services.displayManager.sddm.wayland.enable = true;
  services.displayManager.defaultSession = "plasma"; # Set the default session to Plasma Wayland

  # Enable sound.
  services.pipewire = {
    enable = true;
    pulse.enable = true;
  };

  # Enable touchpad support (enabled default in most desktopManager).
  services.libinput.enable = true;

  # Enable CUPS to print documents.
  services.printing.enable = true;

  # Set the default shell for all users to zsh
  programs = {
    zsh = {
      enable = true;
      autosuggestions.enable = true;
      syntaxHighlighting.enable = true;
    };
    starship.enable = true;
  };
  users.defaultUserShell = pkgs.zsh;

  # USER ACCOUNTS
  users.users.USER_NAME = {
    isNormalUser = true;
    home = "/home/USER_NAME";
    extraGroups = [
      "wheel" # Enable ‘sudo’ for the user.
      "networkmanager"
    ];
    openssh.authorizedKeys.keyFiles = [
      "/home/USER_NAME/.ssh/authorized_keys"
    ];
  };

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    firefox # browser
    kitty # terminal
    neovim # editor of choice
    neofetch
    htop
    ffmpeg
    pkgs.tailscale
    pkgs.yt-dlp
    protonvpn-cli
    zellij
  ];

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  programs.gnupg.agent = {
    enable = true;
  };

  # OPENSSH
  services.openssh = { 
    enable = true;
    settings.PasswordAuthentication = false;
    settings.KbdInteractiveAuthentication = false;
    settings.PermitRootLogin = "no";
  };
  services.flatpak.enable = true;


  # TAILSCALE
  services.tailscale.enable = true;
  # create a oneshot job to authenticate to Tailscale
  systemd.services.tailscale-autoconnect = {
    description = "Automatic connection to Tailscale";

    # make sure tailscale is running before trying to connect to tailscale
    after = [ "network-pre.target" "tailscale.service" ];
    wants = [ "network-pre.target" "tailscale.service" ];
    wantedBy = [ "multi-user.target" ];

    # set this service as a oneshot job
    serviceConfig.Type = "oneshot";

    # have the job run this shell script
    script = with pkgs; ''
      # wait for tailscaled to settle
      sleep 2

      # check if we are already authenticated to tailscale
      status="$(${tailscale}/bin/tailscale status -json | ${jq}/bin/jq -r .BackendState)"
      if [ $status = "Running" ]; then # if so, then do nothing
        exit 0
      fi

      # otherwise authenticate with tailscale
      ${tailscale}/bin/tailscale up -authkey TAILSCALE_AUTH_KEY;
    '';
  };

  # NETWORKING
  networking.firewall = {
    # enable the firewall
    enable = true;
    # always allow traffic from your Tailscale network
    trustedInterfaces = [ "tailscale0" ];
    # allow the Tailscale UDP port through the firewall
    allowedUDPPorts = [ config.services.tailscale.port ];
    # let you SSH in over the public internet
    allowedTCPPorts = [ 22 ];
  };


  # For more information, see `man configuration.nix` or https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion .
  system.stateVersion = "25.05"; # Did you read the comment?
}
