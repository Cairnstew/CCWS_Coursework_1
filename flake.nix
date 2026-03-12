# flake.nix
{
  inputs = {
    nixpkgs-terraform.url = "github:stackbuilders/nixpkgs-terraform";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
    flake-utils.url = "github:numtide/flake-utils";
  };

  nixConfig = {
    extra-substituters = "https://nixpkgs-terraform.cachix.org";
    extra-trusted-public-keys = "nixpkgs-terraform.cachix.org-1:8Sit092rIdAVENA3ZVeH9hzSiqI/jng6JiCrQ1Dmusw=";
  };

  outputs = { self, nixpkgs-terraform, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let 
        pkgs = nixpkgs.legacyPackages.${system}; 
        gcloud = pkgs.google-cloud-sdk.withExtraComponents (with pkgs.google-cloud-sdk.components; [
          gke-gcloud-auth-plugin
          #kubectl
          gcloud-man-pages
        ]);
        terraform = nixpkgs-terraform.packages.${system}."1.14";
      in
      {
        # Dev shell with all the tools you need
        devShells.default = pkgs.mkShell {
          packages = with pkgs; [
            terraform 
            # pkgs.packer
            opentofu
            gcloud
          ];

          shellHook = ''
            echo "Welcome to the GCE image builder dev shell!"
            echo "Run 'gcloud auth application-default login --scopes="https://www.googleapis.com/auth/cloud-platform"' to authenticate with GCP."
            echo "Run 'terraform init' in the terraform/ directory to initialize the Terraform configuration."
            echo "Get list of projects with 'gcloud projects list' and set the project_id variable in terraform.tfvars."
            '';
        };

        # Script to build + deploy in one shot
        apps.deploy = {
          type = "app";
          program = toString (pkgs.writeShellScript "deploy" ''
            set -euo pipefail

            PROJECT=''${PROJECT:?set PROJECT}
            BUCKET=''${BUCKET:?set BUCKET}
            REGION=''${REGION:-us-central1}

            echo "==> Building GCE image..."
            nix build .#gce-image --print-build-logs
            IMAGE_PATH=$(readlink -f result/*.tar.gz)
            IMAGE_HASH=$(nix hash path result/ | head -c 12)

            echo "==> Running OpenTofu..."
            cd terraform
            tofu init -upgrade
            tofu apply \
              -var="project=$PROJECT" \
              -var="bucket=$BUCKET" \
              -var="region=$REGION" \
              -var="image_path=$IMAGE_PATH" \
              -var="image_hash=$IMAGE_HASH" \
              -auto-approve
          '');
        };
      }
    ) // {
      # GCE image build output (system-specific)
      nixosConfigurations.myvm = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          "${nixpkgs}/nixos/modules/virtualisation/google-compute-image.nix"
          ./nixos/configuration.nix
        ];
      };

      packages.x86_64-linux.gce-image =
        self.nixosConfigurations.myvm.config.system.build.googleComputeImage;
    };
}