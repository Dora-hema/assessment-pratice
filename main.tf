terraform {
  required_providers {
    google = {
      source = "hashicorp/google"
      version = "3.5.0"
    }
  }
}

provider "google" {
  credentials = file("<NAME>.json")

  project = var.project_id
  region  = "us-central1"
  zone    = "us-central1-c"
}

variable "gcp_service_list" {
    description = "The list of apis necessary for the project"
    type        = list(string)
    default = [
        "compute.googleapis.com",
        "cloudapis.googleapis.com",
        "vpcaccess.googleapis.com",
        "servicenetworking.googleapis.com",
        "cloudbuild.googleapis.com",
        "sql-component.googleapis.com",
        "sqladmin.googleapis.com",
        "storage.googleapis.com",
        "secretmanager.googleapis.com",
        "run.googleapis.com",
        "artifactregistry.googleapis.com",
        "redis.googleapis.com"
    ]
}

locals {
  startup_script_template = /assets/startup-script.tpl
}

data "template_file" "startup-script.tpl" {
  template = file(local.startup_script_template)

}

 
resource "google_project_service" "all" {
    for_each                   = toset(var.gcp_service_list)
    project                    = var.project_number   # need to change project id
    service                    = each.key
    disable_on_destroy = false
} 

resource "google_service_account" "test-project" {
  project      = var.project_id
  account_id   = "${var.sa}"
  display_name = "Service Account for Cloud Run"
}

resource "google_compute_disk" "webapp_data_disk" {
  name  = var.data_disk_name
  type  = "pd-ssd"
  zone  = "us-central1-a"
  size  = 4096
}

resource "google_compute_disk" "webapp_boot_disk" {
  name  = var.boot_disk_name
  type  = "pd-balanced"
  zone  = "us-central1-a"
  image = "debian-11-bullseye-v20220719"
  size  = 4096
}
resource "google_compute_instance" "webapp-instance" {
  name         = "webapp"
  machine_type = "e2-medium"
  zone         = "us-central1-a"

  tags = ["web-tag"]

  boot_disk {
      auto_delete = false
      source = google_compute_disk.webapp_boot_disk.self_link
      device_name = var.boot_disk_name
     }
  attached_disk{
      source = google_compute_disk.webapp_data_disk.self_link
      device_name = var.data_disk_name 
   }

  service_account {
    # Google recommends custom service accounts that have cloud-platform scope and permissions granted via IAM Roles.
    email  = google_service_account.test-project.email
    scopes = ["cloud-platform"] 
  }
  
  metadata = {
    enable-oslogin = "TRUE"
  }

  metadata_startup_script = data.startup_script_template   
  
  network_interface {
    network = var.subnet
  }
 
}

resource "google_compute_instance_group" "webapp-group" {
  name        = "webapp-instance-group"
  zone        = "us-central1-a"
  instance    = [google_compute_instance.webapp-instance.self_link]
  named_port {
    name = "https"
    port = "443"
  }
}

# health check
resource "google_compute_region_health_check" "webapp-healthcheck" {
  name     = "webapp-healthcheck"
  provider = google-beta
  region   = "us-central1-a"
  http_health_check {
    port_specification = 443
  }
}

resource "google_compute_region_backend_service" "webapp-backend_service" {
  name                  = "l7-ilb-backend-subnet"
  provider              = google-beta
  region                = "europe-west1"
  protocol              = "HTTP"
  load_balancing_scheme = "INTERNAL_MANAGED"
  timeout_sec           = 10
  health_checks         = [google_compute_region_health_check.webapp-healthcheck.self_link]
  backend {
    group           = google_compute_region_instance_group_manager.webapp-group.self_link
    balancing_mode  = "UTILIZATION"
    capacity_scaler = 1.0
  }
}









# Handle Database
resource "google_sql_database_instance" "webapp-sql-instance" {
  name             = webapp-sql
  database_version = "MYSQL_5_7"
  region           = "us-central1-a"
  project          = var.project_id

  settings {
    tier                  = "db-g1-small"
    disk_autoresize       = true
    disk_autoresize_limit = 0
    disk_size             = 10
    disk_type             = "PD_SSD"
    user_labels           = var.labels
    ip_configuration {
      ipv4_enabled    = false
      private_network = module.network-safer-mysql-simple.network_self_link
    }
    location_preference {
      zone = "us-central1-a"
    }
  }
  
}

resource "google_sql_database" "database" {
  project  = var.project_id
  name     = "todo"
  instance = google_sql_database_instance.webapp-sql-instance.name
}


resource "random_password" "password" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "google_sql_user" "main" {
  project  = var.project_id
  name     = "test_user"
  password = random_password.password.result
  instance = google_sql_database_instance.webapp-sql-instance.name
}
