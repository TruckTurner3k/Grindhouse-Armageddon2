terraform {
  required_providers {
    google = {
      source = "hashicorp/google"
      version = "5.27.0"
    }
  }
}

provider "google" {
  # Configuration options
  region = "us-east2"
  project = "carbon-sensor-419900"
  credentials = "carbon-sensor-419900-86735cb739be.json"
  }



resource "google_compute_network" "app1" {
  name                    = "app1"
  auto_create_subnetworks = false
  routing_mode            = "REGIONAL"
}

resource "google_compute_subnetwork" "public_subnet_1" {
  name                     = "public-subnet-1"
  ip_cidr_range            = "10.32.1.0/24"
  region                   = "europe-west2"
  network                  = google_compute_network.app1.name
  private_ip_google_access = true
}

resource "google_compute_route" "app1_route" {
  name             = "app1-route"
  dest_range       = "0.0.0.0/0"
  network          = google_compute_network.app1.name
  next_hop_gateway = "default-internet-gateway"
}

resource "google_compute_router" "app1_router_eu" {
  name    = "app1-router-eu"
  region  = "europe-west2"
  network = google_compute_network.app1.name
}

resource "google_compute_router_nat" "app1_nat_eu" {
  name                               = "app1-nat-eu"
  router                             = google_compute_router.app1_router_eu.name
  region                             = google_compute_router.app1_router_eu.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
}

resource "google_compute_firewall" "app1_sg01_http" {
  name        = "app1-sg01-http"
  description = "Allow HTTP traffic"
  network     = google_compute_network.app1.name
  direction   = "INGRESS"
  priority    = 1000

  allow {
    protocol = "tcp"
    ports    = ["80"]
  }

  source_ranges = ["0.0.0.0/0"]

  target_tags = ["http-server"]
}

resource "google_compute_firewall" "app1_sg01_ssh" {
  name        = "app1-sg01-ssh"
  description = "Allow SSH traffic"
  network     = google_compute_network.app1.name
  direction   = "INGRESS"
  priority    = 1000

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["0.0.0.0/0"]

  target_tags = ["ssh-server"]
}

resource "google_compute_firewall" "app1_sg01_egress" {
  name        = "app1-sg01-egress"
  description = "Allow all egress traffic"
  network     = google_compute_network.app1.name
  direction   = "EGRESS"
  priority    = 1000

  allow {
    protocol = "all"
  }

  destination_ranges = ["0.0.0.0/0"]

  target_tags = ["egress"]
}

resource "google_compute_instance" "public_instance_1" {
  name         = "public-instance-1"
  machine_type = "e2-medium"
  zone         = "europe-west2-a"

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11"
    }
  }

  network_interface {
    network       = google_compute_network.app1.name
    subnetwork    = google_compute_subnetwork.public_subnet_1.name
    access_config {
      // Ephemeral public IP
    }
  }

  tags = ["http-server", "ssh-server", "egress"]

  metadata = {
    startup-script = file("${path.module}/startup.sh")
  }
}

output "instance_public_ips" {
  value = {
    "europe-west2-public-a" = "http://${google_compute_instance.public_instance_1.network_interface[0].access_config[0].nat_ip}"
  }
  description = "List of HTTP URLs for public IP addresses assigned to the instances."
}
