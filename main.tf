data "yandex_compute_image" "ubuntu2404" {
  family = "ubuntu-2404-lts-oslogin"
}
resource "yandex_vpc_network" "default" {
  name = var.project
}
resource "yandex_vpc_gateway" "default" {
  name = var.project
  shared_egress_gateway {}
}
resource "yandex_vpc_route_table" "default" {
  name       = var.project
  network_id = yandex_vpc_network.default.id
  static_route {
    destination_prefix = "0.0.0.0/0"
    gateway_id         = yandex_vpc_gateway.default.id
  }
}
resource "yandex_vpc_subnet" "default" {
  name           = "${yandex_vpc_network.default.name}-${var.zone}"
  network_id     = yandex_vpc_network.default.id
  v4_cidr_blocks = ["10.130.0.0/24"]
  route_table_id = yandex_vpc_route_table.default.id
}
resource "yandex_compute_instance" "backend" {
  count       = 3
  name        = format("%s-%02d", "${var.project}-backend", count.index + 1)
  hostname    = format("%s-%02d", "${var.project}-backend", count.index + 1)
  platform_id = "standard-v3"
  resources {
    cores         = 2
    memory        = 2
    core_fraction = 20
  }
  scheduling_policy { preemptible = true }
  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu2404.id
      size     = 20
      type     = "network-ssd"
    }
  }
  network_interface {
    subnet_id = yandex_vpc_subnet.default.id
    ip_address = cidrhost(
      one(yandex_vpc_subnet.default.v4_cidr_blocks), 21 + count.index
    )
    nat       = count.index == 0
  }
  metadata = local.yandex_compute_instance_metadata
}
resource "yandex_compute_instance" "elasticsearch" {
  count       = 3
  name        = format("%s-%02d", "${var.project}-es", count.index + 1)
  hostname    = format("%s-%02d", "${var.project}-es", count.index + 1)
  platform_id = "standard-v3"
  resources {
    cores         = 2
    memory        = 8
    core_fraction = 20
  }
  scheduling_policy { preemptible = true }
  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu2404.id
      size     = 20
      type     = "network-ssd"
    }
  }
  network_interface {
    subnet_id = yandex_vpc_subnet.default.id
    ip_address = cidrhost(
      one(yandex_vpc_subnet.default.v4_cidr_blocks), 31 + count.index
    )
    nat       = false
  }
  metadata = local.yandex_compute_instance_metadata
}
resource "yandex_lb_target_group" "backend" {
  name      = "${var.project}-backend"
  dynamic "target" {
    for_each = yandex_compute_instance.backend
    content {
      subnet_id = yandex_vpc_subnet.default.id
      address = target.value.network_interface.0.ip_address
    }
  }
}
resource "yandex_lb_network_load_balancer" "backend" {
  name = "${var.project}-backend"
  listener {
    name = "${var.project}-backend-https"
    port = 443
    external_address_spec {
      ip_version = "ipv4"
    }
  }
  listener {
    name = "${var.project}-backend-kibana"
    port = 5601
    external_address_spec {
      ip_version = "ipv4"
    }
  }
  listener {
    name = "${var.project}-backend-vts"
    port = 9443
    external_address_spec {
      ip_version = "ipv4"
    }
  }
  attached_target_group {
    target_group_id = yandex_lb_target_group.backend.id
    healthcheck {
      name = "https"
      healthy_threshold = 2
      unhealthy_threshold = 2
      interval = 2
      timeout = 1
      tcp_options {
        port = 443
      }
    }
  }
}
resource "local_file" "inventory" {
  filename = "${path.root}/inventory.yml"
  content = templatefile("${path.module}/inventory.tftpl", {
    ssh_username = var.ssh_username,
    ssh_key_file = var.ssh_key_file,
    groups = [
      {
        name     = "backend",
        hosts    = yandex_compute_instance.backend
        jumphost = yandex_compute_instance.backend.0
      },
      {
        name     = "elasticsearch",
        hosts    = yandex_compute_instance.elasticsearch
        jumphost = yandex_compute_instance.backend.0
      }
    ],
  })
}
