resource "opentelekomcloud_vpc_v1" "kubernetes" {
  name = "kubernetes"
  cidr = "10.30.0.0/24"
}

resource "opentelekomcloud_vpc_subnet_v1" "kubernetes" {
  name       = "kubernetes"
  cidr       = "10.30.0.0/24"
  vpc_id     = opentelekomcloud_vpc_v1.kubernetes.id
  gateway_ip = "10.30.0.1"
}

resource "opentelekomcloud_swr_organization_v2" "victororg" {
  name = "victororg"
}

resource "opentelekomcloud_vpc_bandwidth_v2" "kubernetes" {
  name = "kubernetes"
  size = 5
}

resource "opentelekomcloud_networking_floatingip_v2" "cluster1" {}

resource "opentelekomcloud_cce_cluster_v3" "cluster1" {
  name                   = "cluster1"
  cluster_type           = "VirtualMachine"
  flavor_id              = "cce.s1.small"
  vpc_id                 = opentelekomcloud_vpc_v1.kubernetes.id
  subnet_id              = opentelekomcloud_vpc_subnet_v1.kubernetes.id
  container_network_type = "vpc-router"
  eip                    = opentelekomcloud_networking_floatingip_v2.cluster1.address
}

resource "opentelekomcloud_networking_floatingip_v2" "cluster1-node1" {}

resource "opentelekomcloud_cce_node_v3" "cluster1-node1" {
  name              = "cluster1-node1"
  cluster_id        = opentelekomcloud_cce_cluster_v3.cluster1.id
  availability_zone = "eu-de-02"

  # Use the smallest possible worker node flavor in dev
  flavor_id = terraform.workspace == "prod" ? "s2.large.2" : "s2.large.2"
  # The specified SSH key pair will be authorized for login as the
  # user "linux".
  key_pair  = opentelekomcloud_compute_keypair_v2.victors.id

  eip_ids = [opentelekomcloud_networking_floatingip_v2.cluster1-node1.id]

  root_volume {
    # Use smallest possible disk size in dev
    size       = terraform.workspace == "prod" ? 40 : 40
    volumetype = "SATA"
  }

  data_volumes {
    # Use smallest possible disk size in dev
    size       = 100
    volumetype = "SATA"
  }
}

# Load balancer stuff
resource "opentelekomcloud_networking_floatingip_v2" "loadbalancer1" {}

resource "opentelekomcloud_lb_loadbalancer_v2" "loadbalancer1" {
  name          = "loadbalancer1"
  vip_subnet_id = opentelekomcloud_vpc_subnet_v1.kubernetes.subnet_id
}

resource "opentelekomcloud_networking_floatingip_associate_v2" "loadbalancer1" {
  floating_ip = opentelekomcloud_networking_floatingip_v2.loadbalancer1.address
  port_id     = opentelekomcloud_lb_loadbalancer_v2.loadbalancer1.vip_port_id
}

resource "opentelekomcloud_vpc_bandwidth_associate_v2" "kubernetes" {
  bandwidth = opentelekomcloud_vpc_bandwidth_v2.kubernetes.id
  floating_ips = [
    opentelekomcloud_networking_floatingip_v2.cluster1.id,
    opentelekomcloud_networking_floatingip_v2.cluster1-node1.id,
    opentelekomcloud_networking_floatingip_v2.loadbalancer1.id
  ]
}

