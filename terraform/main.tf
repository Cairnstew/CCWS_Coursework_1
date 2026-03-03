terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

variable "project" {
  type = string
}

variable "bucket" {
  type = string
}

variable "region" {
  type    = string
  default = "us-central1"
}

variable "zone" {
  type    = string
  default = "us-central1-a"
}

variable "image_path" {
  type = string
}

variable "image_hash" {
  type        = string
  description = "Short git SHA used to name the GCE image"
}

variable "ssh_public_key" {
  type        = string
  description = "SSH public key for the nixos user"
}

provider "google" {
  project = var.project
  region  = var.region
}

# Look up existing default network, don't manage it
data "google_compute_network" "default" {
  name = "default"
}

# GCS bucket to store images
resource "google_storage_bucket" "images" {
  name                        = var.bucket
  location                    = var.region
  force_destroy               = true
  uniform_bucket_level_access = true

  lifecycle {
    ignore_changes = [name]
  }
}

# Upload the .tar.gz built by nix
resource "google_storage_bucket_object" "nixos_image" {
  name   = "nixos-${var.image_hash}.tar.gz"
  source = var.image_path
  bucket = google_storage_bucket.images.name
}

# Register it as a GCE image
resource "google_compute_image" "nixos" {
  name   = "nixos-${var.image_hash}"
  family = "nixos"

  raw_disk {
    source = google_storage_bucket_object.nixos_image.self_link
  }

  guest_os_features {
    type = "VIRTIO_SCSI_MULTIQUEUE"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# VM instance
resource "google_compute_instance" "myvm" {
  name         = "myvm"
  machine_type = "e2-small"
  zone         = var.zone

  boot_disk {
    initialize_params {
      image = google_compute_image.nixos.self_link
      size  = 20
    }
  }

  network_interface {
    network = data.google_compute_network.default.name
    access_config {}
  }

  metadata = {
    enable-oslogin = "FALSE"
    ssh-keys       = "nixos:${var.ssh_public_key}"
  }

  tags = ["nixos", "myvm"]
}

# Firewall: SSH only
resource "google_compute_firewall" "ssh" {
  name    = "allow-ssh-myvm"
  network = data.google_compute_network.default.name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  target_tags   = ["myvm"]
  source_ranges = ["0.0.0.0/0"]
}

output "ip" {
  value = google_compute_instance.myvm.network_interface[0].access_config[0].nat_ip
}