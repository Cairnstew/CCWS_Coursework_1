# ============================================================
# CCWS Coursework 1 - Main Terraform Configuration
# Region: europe-west2 (London)
# ============================================================

terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

# ============================================================
# Variables
# ============================================================

variable "project_id" {
  description = "Your GCP Project ID"
  type        = string
}

variable "student_id" {
  description = "Your Student ID e.g. S1234567"
  type        = string
}

variable "user_email" {
  description = "Your Google account email for IAP access"
  type        = string
}

# ============================================================
# Provider
# ============================================================

provider "google" {
  project = var.project_id
  region  = "europe-west2"
  zone    = "europe-west2-b"
}

# ============================================================
# Outputs
# ============================================================

output "compute_instance_ip" {
  description = "Public IP of your Compute Engine instance"
  value       = google_compute_instance.web_server.network_interface[0].access_config[0].nat_ip
}

output "storage_bucket_name" {
  description = "Name of your Cloud Storage bucket"
  value       = google_storage_bucket.images_bucket.name
}

output "storage_bucket_url" {
  description = "Public URL of your Cloud Storage bucket"
  value       = "https://storage.googleapis.com/${google_storage_bucket.images_bucket.name}"
}

output "app1_url" {
  description = "App Engine App 1 - Name, Student ID and Time (Task 1d)"
  value       = "https://${var.project_id}.nw.r.appspot.com/"
}

output "app2_url" {
  description = "App Engine App 2 - Image viewer (Task 2d)"
  value       = "https://${var.project_id}.nw.r.appspot.com/images/1"
}

output "app3_url" {
  description = "App Engine App 3 - Image metadata JSON (Task 3b)"
  value       = "https://${var.project_id}.nw.r.appspot.com/metadata/1"
}
