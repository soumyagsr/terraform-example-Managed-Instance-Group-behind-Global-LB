  GNU nano 2.7.4                                                                                                                                                                                                                                                                                    File: main.tf                                                                                                                                                                                                                                                                                               
provider "google" {
  project = "${var.project_name}"
}
provider "google-beta" {
  project = "${var.project_name}"
}
# Create a new VPC network
resource "google_compute_network" "tf-test-nw" {
  name                    = "tf-vpc"
  auto_create_subnetworks = "false"     # Will create subnets only in required regions
  #routing_mode            = "GLOBAL"
}
# Create subnet in region 1
resource "google_compute_subnetwork" "tf-subnet1" {
  name          = "tf-subnet1"
  ip_cidr_range = "10.2.0.0/16"
  region        = "${var.region1}"
  depends_on    = [google_compute_network.tf-test-nw]
  network       = "${google_compute_network.tf-test-nw.self_link}"
}
# Create subnet in region 2
resource "google_compute_subnetwork" "tf-subnet2" {
  name          = "tf-subnet2"
  ip_cidr_range = "192.168.10.0/24"
  region        = "${var.region2}"
  depends_on    = [google_compute_network.tf-test-nw]
  network       = "${google_compute_network.tf-test-nw.self_link}"
}
# Create a managed instance group template for region 1
resource "google_compute_instance_template" "mig-template1" {
  provider                = "google"
  name                    = "tf-mig-template1"
  description             = "Template used to create the instances within the managed instance group."
  instance_description    = "description assigned to instances"
  machine_type            = "n1-standard-1"
  tags                    = ["http-tag"]    # Tag(s) specified here must match the target_tags in the firewall rule
  can_ip_forward          = false
  depends_on              = [google_compute_network.tf-test-nw, google_compute_subnetwork.tf-subnet1]
  region                  = "${var.region1}"
  metadata_startup_script = "sudo apt-get update && sudo apt-get install apache2 -y && echo '<!doctype html><html><body><h1>Hello from Terraform on Google Cloud!</h1></body></html>' | sudo tee /var/www/html/index.html"
  scheduling {
    automatic_restart   = true
    on_host_maintenance = "MIGRATE"
  }
  // Create a new boot disk from an image
  disk {
    source_image = "debian-cloud/debian-9"
    auto_delete  = true
    boot         = true
  }
  network_interface {
    network    = "tf-vpc"
    subnetwork = "tf-subnet1"
    access_config {
      // Include this section to give the VM an external ip address
    }
  }
  service_account {
    scopes     = ["userinfo-email", "compute-ro", "storage-ro"]
  }
}
# Create a managed instance group template for region 2
resource "google_compute_instance_template" "mig-template2" {
  provider                = "google"
  name                    = "tf-mig-template2"
  description             = "Template used to create the instances within the managed instance group."
  instance_description    = "description assigned to instances"
  machine_type            = "n1-standard-1"
  tags                    = ["http-tag"]    # Tag(s) specified here must match the target_tags in the firewall rule
  can_ip_forward          = false
  depends_on              = [google_compute_network.tf-test-nw, google_compute_subnetwork.tf-subnet2]
  region                  = "${var.region2}"
  metadata_startup_script = "sudo apt-get update && sudo apt-get install apache2 -y && echo '<!doctype html><html><body><h1>Hello from Terraform on Google Cloud!</h1></body></html>' | sudo tee /var/www/html/index.html"
  scheduling {
    automatic_restart   = true
    on_host_maintenance = "MIGRATE"
  }
  // Create a new boot disk from an image
  disk {
    source_image = "debian-cloud/debian-9"
    auto_delete  = true
    boot         = true
  }
  network_interface {
    network    = "tf-vpc"
    subnetwork = "tf-subnet2"
    access_config {
      // Include this section to give the VM an external ip address
    }
  }
  service_account {
    scopes     = ["userinfo-email", "compute-ro", "storage-ro"]
  }
}
# Create an HTTP health check
resource "google_compute_health_check" "health-check" {
  provider            = "google"
  name                = "tf-health-check"
  check_interval_sec  = 10
  timeout_sec         = 10
  healthy_threshold   = 2
  unhealthy_threshold = 5             # 5 seconds
  http_health_check {
  }
}
# Create 1st regional managed instance group using the template defined above
resource "google_compute_region_instance_group_manager" "mig-mgr1" {
  provider                  = "google-beta"
  name                      = "tf-mig-mgr1"
  base_instance_name        = "tf-mig1"
  version {
    name               = "ver1"
    instance_template  = "${google_compute_instance_template.mig-template1.self_link}"
  }
  region                    = "${var.region1}"
  distribution_policy_zones = ["${var.region1_zone1}", "${var.region1_zone2}", "${var.region1_zone3}"]
  depends_on                = [google_compute_health_check.health-check, google_compute_instance_template.mig-template1]
  named_port {
    name = "http"
    port = "80"
  }
  auto_healing_policies {
    health_check      = "${google_compute_health_check.health-check.self_link}"
    initial_delay_sec = 300
  }
}
# Create an autoscaler associated with the 1st managed instance group
resource "google_compute_region_autoscaler" "autoscaler1" {
  provider = "google-beta"
  name   = "tf-autoscaler1"
  region = "${var.region1}"
  target = "${google_compute_region_instance_group_manager.mig-mgr1.self_link}"
  autoscaling_policy {
    max_replicas    = 5
    min_replicas    = 2
    cooldown_period = 60
    cpu_utilization {
      target = 0.5
    }
  }
  
  # Create the 1st backend service pointing to the 1st MIG defined above
resource "google_compute_backend_service" "backend1" {
  provider      = "google"
  name          = "tf-backend1"
  #enable_cdn    = true
  timeout_sec   = 3600
  health_checks = ["${google_compute_health_check.health-check.self_link}"]
  backend {
    group = "${google_compute_region_instance_group_manager.mig-mgr1.instance_group}"
  }

  # Open bug on applying multiple backends: https://github.com/terraform-providers/terraform-provider-google/issues/3937
  # As of now, you have to create two different backends
  # backend {
  #  group = "${google_compute_region_instance_group_manager.mig-mgr2.instance_group}"
  # }
}


# Create 2nd regional managed instance group using the 2nd template defined above
resource "google_compute_region_instance_group_manager" "mig-mgr2" {
  provider                  = "google-beta"
  name                      = "tf-mig-mgr2"
  base_instance_name        = "tf-mig2"
  version {
    name               = "ver1"
    instance_template  = "${google_compute_instance_template.mig-template2.self_link}"
  }
  region                    = "${var.region2}"
  distribution_policy_zones = ["${var.region2_zone1}", "${var.region2_zone2}", "${var.region2_zone3}"]
  depends_on                = [google_compute_health_check.health-check, google_compute_instance_template.mig-template2]
  named_port {
    name = "http"
    port = "80"
  }
  auto_healing_policies {
    health_check      = "${google_compute_health_check.health-check.self_link}"
    initial_delay_sec = 300
  }
}


# Create an autoscaler associated with the 2nd managed instance group
resource "google_compute_region_autoscaler" "autoscaler2" {
  provider = "google-beta"
  name   = "tf-autoscaler2"
  region = "${var.region2}"
  target = "${google_compute_region_instance_group_manager.mig-mgr2.self_link}"
  autoscaling_policy {
    max_replicas    = 5
    min_replicas    = 2
    cooldown_period = 60
    cpu_utilization {
      target = 0.5
    }
  }
}


# Create the 2nd backend service pointing to the 1st MIG defined above
resource "google_compute_backend_service" "backend2" {
  provider      = "google"
  name          = "tf-backend2"
  #enable_cdn    = true
  timeout_sec   = 3600
  health_checks = ["${google_compute_health_check.health-check.self_link}"]
  backend {
    group = "${google_compute_region_instance_group_manager.mig-mgr2.instance_group}"
  }
}


# Define the url map - use the path matcher to point to different backend services
# Example of content based load balancing to different backends is contained in the repo listed in References
resource "google_compute_url_map" "default" {
  provider = "google"
  name = "tf-test-url-map"
  default_service = "${google_compute_backend_service.backend1.self_link}"
  host_rule {
    hosts = ["*"]
    path_matcher = "tf-allpaths"
  }
  path_matcher {
    name = "tf-allpaths"
    default_service = "${google_compute_backend_service.backend1.self_link}"
    path_rule {
      paths   = ["/video", "/video/*"]
      service = "${google_compute_backend_service.backend2.self_link}"
    }
  }
}


# Define the HTTP(S) proxy where the forwarding rule forwards requests
resource "google_compute_target_http_proxy" "http-lb-proxy" {
  provider = "google"
  name = "tf-http-lb-proxy"
  url_map = "${google_compute_url_map.default.self_link}"
}


# Create a static global address (single anycast IP)
resource "google_compute_global_address" "external-address" {
  provider = "google"
  name = "tf-external-address"
}


# Define the load balancer forwarding rule that sends traffic to the proxy defined above
resource "google_compute_global_forwarding_rule" "default" {
  provider    = "google"
  name        = "tf-http-gfr"
  target      = "${google_compute_target_http_proxy.http-lb-proxy.self_link}"
  ip_address  = "${google_compute_global_address.external-address.address}"
  port_range  = "80"
}


# Define firewall rule to allow traffic from the load balancer and health check
resource "google_compute_firewall" "default" {
  provider      = "google"
  name          = "tf-test-firewall-allow-internal-only"
  #network       = "{google_compute_network.tf-test-nw.self_link}"
  network       = "tf-vpc"
  depends_on    = [google_compute_network.tf-test-nw]
  allow {
    protocol    = "tcp"
    ports       = ["80"]
  }
  source_ranges = ["130.211.0.0/22", "35.191.0.0/16"]
  target_tags   = ["http-tag"]
}


/*
# Define firewall rule to allow SSH traffic
resource "google_compute_firewall" "ssh" {
  provider      = "google"
  name          = "tf-test-firewall-allow-ssh"
  network       = "tf-vpc"
  #network       = "{google_compute_network.tf-test-nw.self_link}"
  depends_on    = [google_compute_network.tf-test-nw]
  allow {
    protocol    = "tcp"
    ports       = ["22"]
  }
  target_tags   = ["http-tag"]
}
*/
