# ============================================================
# App Engine Infrastructure
# Enables APIs and grants service account permissions
# Note: staging bucket is created automatically by Google on first deploy
# ============================================================

# ============================================================
# Enable required APIs
# ============================================================

resource "google_project_service" "appengine_api" {
  project            = var.project_id
  service            = "appengine.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "cloudbuild_api" {
  project            = var.project_id
  service            = "cloudbuild.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "storage_api" {
  project            = var.project_id
  service            = "storage.googleapis.com"
  disable_on_destroy = false
}

# ============================================================
# Grant App Engine service account required permissions
# ============================================================

# Allows App Engine to read/write Cloud Storage
resource "google_project_iam_member" "appengine_storage" {
  project = var.project_id
  role    = "roles/storage.admin"
  member  = "serviceAccount:${var.project_id}@appspot.gserviceaccount.com"
}

# Allows App Engine to submit Cloud Builds
resource "google_project_iam_member" "appengine_cloudbuild" {
  project = var.project_id
  role    = "roles/cloudbuild.builds.builder"
  member  = "serviceAccount:${var.project_id}@appspot.gserviceaccount.com"
}
