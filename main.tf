
provider "google" {
  credentials = "${file("devops_narencred.json")}"
  project     = "natural-oath-266908"
  region      = "us-central1"
}
resource "random_id" "instance_id" {
  byte_length = 8

}

resource "google_compute_network" "vpc" {
  name          = "narendevops"
  auto_create_subnetworks = "false"
  routing_mode            = "GLOBAL"
}

resource "google_compute_address" "test-static-ip-address" {
  name = "my-test-static-ip-address"
}


resource "google_compute_instance" "default" {
  name         = "dns-proxy-nfs"
  machine_type = "n1-standard-1"
  zone         = "us-central1-a"

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-9"
    }
  }

 network_interface {
    network = "default"

    access_config {
      nat_ip = "${google_compute_address.test-static-ip-address.address}"
    }
  }
 metadata = {
   ssh-keys = "kolli7571:${file("/root/.ssh/gcloud_instance1.pub")}"
  
}

}
resource "google_compute_firewall" "allow-http" {
  name    = "narendevops-fw-allow-http"
  network = "${google_compute_network.vpc.name}"
allow {
    protocol = "tcp"
    ports    = ["80"]
  }
  target_tags = ["http"] 
}

resource "google_compute_firewall" "allow-bastion" {
  name    = "narendevops-fw-allow-bastion"
  network = "${google_compute_network.vpc.name}"
  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
  target_tags = ["ssh"]
  }
resource "null_resource" "remote-exec-1" {
    connection {
    user        = "kolli7571"
    type        = "ssh"
    private_key = "${file("/root/.ssh/gcloud_instance1")}"
    host        = "${google_compute_address.test-static-ip-address.address}"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo apt-get update",
      "sudo apt-get install python sshpass -y",
    ]
  }
}

resource "null_resource" "ansible-main" {
provisioner "local-exec" {
  command = <<EOT
        sleep 100;
        > jenkins-ci.ini;
        echo "[jenkins-ci]"| tee -a jenkins-ci.ini;
        export ANSIBLE_HOST_KEY_CHECKING=False;
        echo "${google_compute_address.test-static-ip-address.address}" | tee -a jenkins-ci.ini;
        ansible-playbook   -i jenkins-ci.ini ./Ansible_Tomcat/web-playbook.yaml -u kolli7571 --private-key=/root/.ssh/gcloud_instance1 -v
    EOT
}
}
