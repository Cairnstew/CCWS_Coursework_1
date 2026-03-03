# nixos/configuration.nix
{ pkgs, ... }: {
  # Your NixOS config here
  users.users.seanc = {
    isNormalUser = true;
    extraGroups  = [ "wheel" ];
    openssh.authorizedKeys.keys = [
      "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCbNv/alAqtPmgCC04P0S91I7VwoMB9mbUEWQdCzXOWrpcl3gQb79ynJfEuBMHP4oxwHZ840jr6D2mrSy04GWjDRtp9hDK/81aeVpZiMi+m7FiAw6bf0zB51Yeh1jYmVEgNf2O50PuM8KfjVTx2BjGSkyTbmbOleiKOTiy5xkgBJka8JFrLkPE8hWykfH/sCiQ3C9eFyGRqOTu20KXij8R4aHL5+KEY5/1mgylce8ia5UGaEEMBTZ+4QWoNkkZdGE75HrfmevxgXM58IcnrdknuGz2CThpalxjob7hGU2KZuem9yt+XnyaSG+EbE3js7K1JEnmjqnX++PdYfcgNb85cD+mCzpBXHeCmfUxYtnr+qMems+Q+P8ci3tPom6CNbJl+3sZ4nnlgMYSZSPhc1zgzkHmaW3Z0uV0WDL90dHSWuoGRu+ovXihHepUPtXN9/JW+By3k9M8hzhq0tB6i7d5RmUSr/0BYRrTuFIn/OCGfjtebP8rJq+vJyP83nEM/fp8= seanc@DESKTOP-DLSTFLT"
    ];
    shell = pkgs.bashInteractive;
  };

  services.openssh.enable = true;

  environment.systemPackages = with pkgs; [ vim curl ];

  system.stateVersion = "24.11";
}