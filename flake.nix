# flake.nix
# ============================================================
# CCWS Coursework 1 - Nix Flake
#
# Per-subtask scripts (run with `nix run .#<n>`):
#
#   TASK 1
#   nix run .#task1a   — provision Compute Engine instance via Terraform
#   nix run .#task1b   — verify Nginx web server is running
#   nix run .#task1c   — upload dog.jpg and open it in browser
#   nix run .#task1d   — deploy App 1 (name / student ID / time) and browse
#
#   TASK 2
#   nix run .#task2a   — provision Cloud Storage bucket via Terraform
#   nix run .#task2b   — upload three images and make them public
#   nix run .#task2c   — copy HTML gallery to VM and open it in browser
#   nix run .#task2d   — deploy App 2 (image viewer) and browse
#
#   TASK 3
#   nix run .#task3a   — open APIs Explorer for storage.objects.get
#   nix run .#task3b   — deploy App 3 (metadata JSON) and browse
#   nix run .#task3c   — configure IAP (enable, grant access, OAuth setup)
#
#   CONVENIENCE
#   nix run .#all      — run all tasks in order (full deployment)
#   nix run .#ssh      — SSH into the Compute Engine instance
# ============================================================
{
  inputs = {
    nixpkgs-terraform.url  = "github:stackbuilders/nixpkgs-terraform";
    nixpkgs.url            = "github:NixOS/nixpkgs/nixos-24.11";
    flake-utils.url        = "github:numtide/flake-utils";
  };

  nixConfig = {
    extra-substituters        = "https://nixpkgs-terraform.cachix.org";
    extra-trusted-public-keys = "nixpkgs-terraform.cachix.org-1:8Sit092rIdAVENA3ZVeH9hzSiqI/jng6JiCrQ1Dmusw=";
  };

  outputs = { self, nixpkgs-terraform, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};

        gcloud = pkgs.google-cloud-sdk.withExtraComponents (with pkgs.google-cloud-sdk.components; [
          gke-gcloud-auth-plugin
          gcloud-man-pages
        ]);

        terraform = nixpkgs-terraform.packages.${system}."1.14";

        # --------------------------------------------------------
        # Shared constants — edit terraform.tfvars to change these
        # --------------------------------------------------------
        project   = "ccws-coursework-1";
        bucket    = "${project}-ccws-images";
        zone      = "europe-west2-b";
        instance  = "ccws-web-server";
        userEmail = "seanstrcairns@gmail.com";

        # --------------------------------------------------------
        # Helper: wrap a shell script string into a nix app.
        # Every script gets a REPO variable pointing to the
        # git repo root at runtime (walked up from $PWD).
        # This avoids using ${self} which resolves to the
        # read-only nix store and breaks `terraform init`.
        # --------------------------------------------------------
        repoHeader = ''
          # Locate the repo root (directory containing flake.nix)
          REPO="$PWD"
          while [ "$REPO" != "/" ] && [ ! -f "$REPO/flake.nix" ]; do
            REPO="$(dirname "$REPO")"
          done
          if [ ! -f "$REPO/flake.nix" ]; then
            echo "❌ Could not find repo root (no flake.nix found)."
            echo "   Run this script from inside the CCWS_Coursework_1 directory."
            exit 1
          fi
        '';

        mkApp = name: script:
          let s = pkgs.writeShellScriptBin name (repoHeader + script);
          in { type = "app"; program = "${s}/bin/${name}"; };

        # ========================================================
        # TASK 1
        # ========================================================

        # Task 1a — Create Linux Compute Engine instance
        task1a = mkApp "task1a" ''
          set -euo pipefail
          echo ""
          echo "=========================================="
          echo "  TASK 1a — Provision Compute Engine"
          echo "  Machine : e2-micro (low cost)"
          echo "  Zone    : ${zone}"
          echo "  HTTP + HTTPS traffic allowed"
          echo "=========================================="
          cd "$REPO/terraform"
          terraform init -input=false
          terraform apply -input=false -auto-approve \
            -target=google_compute_instance.web_server \
            -target=google_compute_firewall.allow_http \
            -target=google_compute_firewall.allow_https \
            -target=google_compute_firewall.allow_ssh
          echo ""
          echo "✅ Instance created."
          echo "   Public IP: $(terraform output -raw compute_instance_ip)"
        '';

        # Task 1b — Verify Nginx is running
        task1b = mkApp "task1b" ''
          set -euo pipefail
          echo ""
          echo "=========================================="
          echo "  TASK 1b — Verify Nginx web server"
          echo "=========================================="
          IP=$(cd "$REPO/terraform" && terraform output -raw compute_instance_ip)
          echo "Instance IP: $IP"
          echo "Waiting up to 60s for Nginx to respond..."
          for i in $(seq 1 12); do
            if curl -sf --max-time 5 "http://$IP" > /dev/null; then
              echo "✅ Nginx is serving HTTP on http://$IP"
              ${pkgs.xdg-utils}/bin/xdg-open "http://$IP" 2>/dev/null || true
              exit 0
            fi
            echo "  Attempt $i/12 — retrying in 5s..."
            sleep 5
          done
          echo "❌ Nginx did not respond within 60s. Check startup script logs."
          exit 1
        '';

        # Task 1c — Upload image and serve it via Nginx
        task1c = mkApp "task1c" ''
          set -euo pipefail
          echo ""
          echo "=========================================="
          echo "  TASK 1c — Upload image to VM"
          echo "  Served at: http://<VM_IP>/images/dog.jpg"
          echo "=========================================="
          if [ ! -f /tmp/dog.jpg ]; then
            echo "Downloading dog.jpg..."
            curl -fsSL \
              "https://upload.wikimedia.org/wikipedia/commons/thumb/2/26/YellowLabradorLooking_new.jpg/1200px-YellowLabradorLooking_new.jpg" \
              -o /tmp/dog.jpg
          fi
          echo "Copying to VM at /var/www/html/images/dog.jpg..."
          gcloud compute scp /tmp/dog.jpg ${instance}:/var/www/html/images/dog.jpg \
            --zone=${zone} --project=${project}
          IP=$(cd "$REPO/terraform" && terraform output -raw compute_instance_ip)
          echo ""
          echo "✅ Image served at: http://$IP/images/dog.jpg"
          ${pkgs.xdg-utils}/bin/xdg-open "http://$IP/images/dog.jpg" 2>/dev/null || true
        '';

        # Task 1d — Deploy App 1 (name / student ID / timestamp)
        task1d = mkApp "task1d" ''
          set -euo pipefail
          echo ""
          echo "=========================================="
          echo "  TASK 1d — Deploy App 1"
          echo "  Displays: name, student ID, access time"
          echo "  Runtime : Python 3.11 on App Engine"
          echo "=========================================="
          cd "$REPO/app1"
          # Pass 'local' to run the dev server instead of deploying
          if [ "''${1:-deploy}" = "local" ]; then
            echo "Starting local dev server on http://localhost:8080 ..."
            python3 -m flask --app main run --port 8080
            exit 0
          fi
          echo "Deploying to App Engine..."
          gcloud app deploy --quiet --project=${project}
          echo ""
          echo "✅ App 1 deployed: https://${project}.nw.r.appspot.com/"
          gcloud app browse --project=${project}
        '';

        # ========================================================
        # TASK 2
        # ========================================================

        # Task 2a — Create Cloud Storage bucket (EU multi-region, STANDARD)
        task2a = mkApp "task2a" ''
          set -euo pipefail
          echo ""
          echo "=========================================="
          echo "  TASK 2a — Provision Cloud Storage bucket"
          echo "  Bucket  : ${bucket}"
          echo "  Location: EU (multi-region, 2+ regions)"
          echo "  Class   : STANDARD (frequent access)"
          echo "=========================================="
          cd "$REPO/terraform"
          terraform init -input=false
          terraform apply -input=false -auto-approve \
            -target=google_storage_bucket.images_bucket \
            -target=google_storage_bucket_iam_member.public_read \
            -target=google_project_service.storage_api
          echo ""
          echo "✅ Bucket created: gs://${bucket}"
          echo "   URL: $(terraform output -raw storage_bucket_url)"
        '';

        # Task 2b — Upload three images and verify public access
        task2b = mkApp "task2b" ''
          set -euo pipefail
          echo ""
          echo "=========================================="
          echo "  TASK 2b — Upload images to bucket"
          echo "  All three images made publicly accessible"
          echo "=========================================="
          gsutil cp "$REPO/images/dog.jpg"      gs://${bucket}/
          gsutil cp "$REPO/images/mountain.jpg" gs://${bucket}/
          gsutil cp "$REPO/images/city.jpg"     gs://${bucket}/
          echo ""
          echo "✅ Uploaded to gs://${bucket}/"
          echo ""
          echo "Verifying public HTTP access..."
          for img in dog.jpg mountain.jpg city.jpg; do
            URL="https://storage.googleapis.com/${bucket}/$img"
            STATUS=$(curl -sf -o /dev/null -w "%{http_code}" "$URL" || echo "000")
            echo "  $img → HTTP $STATUS  ($URL)"
          done
        '';

        # Task 2c — Copy HTML gallery to VM and open in browser
        task2c = mkApp "task2c" ''
          set -euo pipefail
          echo ""
          echo "=========================================="
          echo "  TASK 2c — Copy HTML gallery to VM"
          echo "  Served at: http://<VM_IP>/index/"
          echo "=========================================="
          gcloud compute ssh ${instance} \
            --zone=${zone} \
            --project=${project} \
            --command="mkdir -p /var/www/html/index"
          gcloud compute scp "$REPO/app2/index.html" \
            ${instance}:/var/www/html/index/index.html \
            --zone=${zone} --project=${project}
          IP=$(cd "$REPO/terraform" && terraform output -raw compute_instance_ip)
          echo ""
          echo "✅ Gallery available at: http://$IP/index/"
          ${pkgs.xdg-utils}/bin/xdg-open "http://$IP/index/" 2>/dev/null || true
        '';

        # Task 2d — Deploy App 2 (image viewer with /images/1,2,3 routes)
        task2d = mkApp "task2d" ''
          set -euo pipefail
          echo ""
          echo "=========================================="
          echo "  TASK 2d — Deploy App 2 (image viewer)"
          echo "  Routes: /images/1  /images/2  /images/3"
          echo "=========================================="
          cd "$REPO/app2"
          if [ "''${1:-deploy}" = "local" ]; then
            echo "Starting local dev server on http://localhost:8080 ..."
            python3 -m flask --app main run --port 8080
            exit 0
          fi
          echo "Deploying to App Engine..."
          gcloud app deploy --quiet --project=${project}
          echo ""
          echo "✅ App 2 deployed."
          echo "Checking each image route..."
          for n in 1 2 3; do
            URL="https://${project}.nw.r.appspot.com/images/$n"
            STATUS=$(curl -sf -o /dev/null -w "%{http_code}" "$URL" || echo "000")
            echo "  /images/$n → HTTP $STATUS"
          done
          gcloud app browse --project=${project}
        '';

        # ========================================================
        # TASK 3
        # ========================================================

        # Task 3a — Demonstrate APIs Explorer / REST API call
        task3a = mkApp "task3a" ''
          set -euo pipefail
          echo ""
          echo "=========================================="
          echo "  TASK 3a — GCS REST API (storage.objects.get)"
          echo "=========================================="
          echo "Method : storage.objects.get"
          echo "API    : Cloud Storage JSON API v1"
          echo ""
          echo "URL template:"
          echo "  GET https://storage.googleapis.com/storage/v1/b/{bucket}/o/{object}"
          echo ""
          echo "Example for dog.jpg in this project:"
          echo "  GET https://storage.googleapis.com/storage/v1/b/${bucket}/o/dog.jpg"
          echo ""
          echo "Opening APIs Explorer 'Try It' page in browser..."
          ${pkgs.xdg-utils}/bin/xdg-open \
            "https://cloud.google.com/storage/docs/json_api/v1/objects/get#try-it" \
            2>/dev/null || true
          echo ""
          echo "Live metadata fetch for dog.jpg (subset shown):"
          curl -s "https://storage.googleapis.com/storage/v1/b/${bucket}/o/dog.jpg" \
            | ${pkgs.jq}/bin/jq '{name,contentType,size,timeCreated}'
        '';

        # Task 3b — Deploy App 3 (metadata JSON via GCS REST API)
        task3b = mkApp "task3b" ''
          set -euo pipefail
          echo ""
          echo "=========================================="
          echo "  TASK 3b — Deploy App 3 (metadata API)"
          echo "  Routes: /metadata/1  /metadata/2  /metadata/3"
          echo "  Response: JSON with filename, type, size,"
          echo "            timeCreated, studentId, requestTime"
          echo "=========================================="
          cd "$REPO/app3"
          if [ "''${1:-deploy}" = "local" ]; then
            echo "Starting local dev server on http://localhost:8080 ..."
            python3 -m flask --app main run --port 8080
            exit 0
          fi
          echo "Deploying to App Engine..."
          gcloud app deploy --quiet --project=${project}
          echo ""
          echo "✅ App 3 deployed."
          echo ""
          echo "Checking each metadata route..."
          IAP_BLOCKED=false
          for n in 1 2 3; do
            URL="https://${project}.nw.r.appspot.com/metadata/$n"
            HTTP_STATUS=$(curl -s -o /tmp/ccws_meta_$n.txt -w "%{http_code}" "$URL")
            if [ "$HTTP_STATUS" = "200" ]; then
              echo "  /metadata/$n → HTTP 200 ✅"
              ${pkgs.jq}/bin/jq '.' /tmp/ccws_meta_$n.txt 2>/dev/null || cat /tmp/ccws_meta_$n.txt
            elif echo "$HTTP_STATUS" | grep -qE '^(302|401|403)$'; then
              echo "  /metadata/$n → HTTP $HTTP_STATUS — IAP is active (expected)"
              IAP_BLOCKED=true
            else
              # Detect IAP HTML redirect inside a 200 wrapper
              if grep -qi "accounts.google.com\|Sign in with Google\|iap\.googleapis" /tmp/ccws_meta_$n.txt 2>/dev/null; then
                echo "  /metadata/$n → IAP redirect detected (HTTP $HTTP_STATUS, expected)"
                IAP_BLOCKED=true
              else
                echo "  /metadata/$n → HTTP $HTTP_STATUS"
                cat /tmp/ccws_meta_$n.txt
              fi
            fi
          done
          echo ""
          if [ "$IAP_BLOCKED" = "true" ]; then
            echo "ℹ️  IAP is protecting the remote app — this is correct for Task 3c."
            echo "   To verify the JSON locally run:  nix run .#task3b local"
          fi
          echo "App URL: https://${project}.nw.r.appspot.com"
        '';

        # Task 3c — Enable and configure IAP
        task3c = mkApp "task3c" ''
          set -euo pipefail
          echo ""
          echo "=========================================="
          echo "  TASK 3c — Configure Identity-Aware Proxy"
          echo "=========================================="

          # Step 1
          echo "[1/5] Enabling IAP API..."
          gcloud services enable iap.googleapis.com --project=${project}

          # Step 2
          echo "[2/5] Enabling IAP on App Engine..."
          gcloud iap web enable \
            --resource-type=app-engine \
            --project=${project}

          # Step 3
          echo "[3/5] Checking OAuth brand..."
          gcloud iap oauth-brands list --project=${project}

          # Step 4
          echo "[4/5] Granting IAP accessor role to ${userEmail}..."
          gcloud iap web add-iam-policy-binding \
            --resource-type=app-engine \
            --project=${project} \
            --member="user:${userEmail}" \
            --role="roles/iap.httpsResourceAccessor"

          echo ""
          echo "=========================================="
          echo "  MANUAL STEPS [5/5]"
          echo "=========================================="
          echo ""
          echo "  A) Create OAuth Client ID:"
          echo "     → https://console.cloud.google.com/apis/credentials?project=${project}"
          echo "     → Create Credentials → OAuth Client ID"
          echo "     → Type: Web application"
          echo "     → Name: IAP-App-Engine-Client"
          echo "     → Add Authorised Redirect URI:"
          echo "       https://iap.googleapis.com/v1/oauth/clientIds/<CLIENT_ID>:handleRedirect"
          echo ""
          echo "  B) Add test user to OAuth consent screen:"
          echo "     → https://console.cloud.google.com/apis/credentials/consent?project=${project}"
          echo "     → Test users → Add: ${userEmail}"
          echo ""
          echo "  C) Re-enable IAP with your OAuth credentials:"
          echo "     gcloud iap web enable \\"
          echo "       --resource-type=app-engine \\"
          echo "       --project=${project} \\"
          echo "       --oauth2-client-id=<YOUR_CLIENT_ID> \\"
          echo "       --oauth2-client-secret=<YOUR_CLIENT_SECRET>"
          echo ""
          echo "  To verify GRANTED access:"
          echo "    Open https://${project}.nw.r.appspot.com (signed in as ${userEmail})"
          echo "    Expected: app loads normally"
          echo ""
          echo "  To verify DENIED access:"
          echo "    Open in an incognito window with a different Google account"
          echo "    Expected: 'You don't have access' screen"
          ${pkgs.xdg-utils}/bin/xdg-open \
            "https://console.cloud.google.com/security/iap?project=${project}" \
            2>/dev/null || true
        '';

        # ========================================================
        # CONVENIENCE
        # ========================================================

        sshScript = mkApp "ssh" ''
          set -euo pipefail
          echo "SSHing into ${instance} (${zone})..."
          gcloud compute ssh ${instance} \
            --zone=${zone} \
            --project=${project}
        '';

        allScript = mkApp "all" ''
          set -euo pipefail
          echo "Running all tasks in sequence..."
          nix run .#task1a
          nix run .#task1b
          nix run .#task1c
          nix run .#task1d
          nix run .#task2a
          nix run .#task2b
          nix run .#task2c
          nix run .#task2d
          nix run .#task3a
          nix run .#task3b
          nix run .#task3c
        '';

      in
      {
        # --------------------------------------------------------
        # Dev shell
        # --------------------------------------------------------
        devShells.default = pkgs.mkShell {
          packages = [
            terraform
            gcloud
            pkgs.python311
            pkgs.python311Packages.flask
            pkgs.python311Packages.requests
            pkgs.jq
          ];

          shellHook = ''
            if ! gcloud auth application-default print-access-token &>/dev/null; then
              echo "🔑 Logging into Google Cloud..."
              gcloud auth application-default login \
                --scopes="https://www.googleapis.com/auth/cloud-platform"
            else
              echo "✅ Already authenticated with Google Cloud"
            fi

            export GOOGLE_APPLICATION_CREDENTIALS="$HOME/.config/gcloud/application_default_credentials.json"

            echo ""
            echo "=============================================="
            echo "  CCWS Coursework 1 — Development Shell"
            echo "=============================================="
            echo ""
            echo "  Task 1:"
            echo "    nix run .#task1a  — provision Compute Engine"
            echo "    nix run .#task1b  — verify Nginx"
            echo "    nix run .#task1c  — upload & serve image"
            echo "    nix run .#task1d  — deploy App 1"
            echo ""
            echo "  Task 2:"
            echo "    nix run .#task2a  — provision Storage bucket"
            echo "    nix run .#task2b  — upload images"
            echo "    nix run .#task2c  — copy HTML gallery to VM"
            echo "    nix run .#task2d  — deploy App 2"
            echo ""
            echo "  Task 3:"
            echo "    nix run .#task3a  — APIs Explorer demo"
            echo "    nix run .#task3b  — deploy App 3"
            echo "    nix run .#task3c  — configure IAP"
            echo ""
            echo "  Other:"
            echo "    nix run .#ssh     — SSH into VM"
            echo "    nix run .#all     — run everything in order"
            echo ""
            echo "  Local testing (pass 'local' as first argument):"
            echo "    nix run .#task1d local"
            echo "    nix run .#task2d local"
            echo "    nix run .#task3b local"
            echo ""
          '';
        };

        # --------------------------------------------------------
        # App outputs
        # --------------------------------------------------------
        apps = {
          # Task 1
          task1a = task1a;
          task1b = task1b;
          task1c = task1c;
          task1d = task1d;

          # Task 2
          task2a = task2a;
          task2b = task2b;
          task2c = task2c;
          task2d = task2d;

          # Task 3
          task3a = task3a;
          task3b = task3b;
          task3c = task3c;

          # Convenience
          ssh = sshScript;
          all = allScript;

          # Keep old names working as aliases
          app1 = task1d;
          app2 = task2d;
          app3 = task3b;
        };
      }
    ) // {
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
