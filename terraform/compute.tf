# ============================================================
# TASK 1a/1b/1c - Compute Engine Instance + Firewall Rules
# ============================================================

resource "google_compute_instance" "web_server" {
  name         = "ccws-web-server"
  machine_type = "e2-micro"   # Low cost, suitable for web serving
  zone         = "europe-west2-b"

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11"
      size  = 10  # GB
    }
  }

  network_interface {
    network = "default"
    access_config {}  # Assigns a public IP
  }

  # Allow HTTP, HTTPS and SSH traffic
  tags = ["http-server", "https-server", "ssh-server"]

  # Task 1b - Install and start Nginx on boot
  metadata_startup_script = <<-EOT
    #!/bin/bash
    apt-get update -y
    apt-get install -y nginx
    systemctl enable nginx
    systemctl start nginx

    # Task 1c - Create a directory for serving images with open permissions
    mkdir -p /var/www/html/images
    chmod 777 /var/www/html
    chmod 777 /var/www/html/images

    # Create a simple default index page
    echo '<html><body><h1>CCWS Coursework 1</h1><p>Web server is running.</p></body></html>' > /var/www/html/index.html
  EOT
}

# Firewall rule - allow SSH (via IAP and direct)
resource "google_compute_firewall" "allow_ssh" {
  name    = "allow-ssh"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["35.235.240.0/20", "0.0.0.0/0"]
  target_tags   = ["ssh-server"]
}

# Firewall rule - allow HTTP
resource "google_compute_firewall" "allow_http" {
  name    = "allow-http"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["80"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["http-server"]
}

# Firewall rule - allow HTTPS
resource "google_compute_firewall" "allow_https" {
  name    = "allow-https"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["443"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["https-server"]
}
