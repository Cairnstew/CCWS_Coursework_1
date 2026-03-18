# ============================================================
# TASK 2a/2b - Cloud Storage Bucket
# Multi-region EU, STANDARD class for frequent access
# ============================================================

resource "google_storage_bucket" "images_bucket" {
  name          = "${var.project_id}-ccws-images"
  location      = "EU"           # Multi-region, replicates across Europe
  storage_class = "STANDARD"     # Appropriate
  force_destroy = true

  uniform_bucket_level_access = true

  cors {
    origin          = ["*"]
    method          = ["GET"]
    response_header = ["Content-Type"]
    max_age_seconds = 3600
  }
}

# Task 2b - Make all objects in bucket publicly readable (For the time being)
resource "google_storage_bucket_iam_member" "public_read" {
  bucket = google_storage_bucket.images_bucket.name
  role   = "roles/storage.objectViewer"
  member = "allUsers"
}
