# flake.nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let 
        pkgs = nixpkgs.legacyPackages.${system}; 
        gcloud = pkgs.google-cloud-sdk.withExtraComponents (with pkgs.google-cloud-sdk.components; [
          gke-gcloud-auth-plugin
          #kubectl
          gcloud-man-pages
        ]);
      in
      {
        # Dev shell with all the tools you need
        devShells.default = pkgs.mkShell {
          packages = with pkgs; [
            opentofu
            gcloud
          ];

          shellHook = ''
            KEY_FILE="ccws-key.json"
            if [ -f "$KEY_FILE" ]; then
              echo "🔑 Found service account key: $KEY_FILE"
              gcloud auth activate-service-account --key-file="$KEY_FILE"
              echo "✅ Service account activated!"
            else
              echo "⚠️ No service account key found → run: gcloud auth login"
            fi
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