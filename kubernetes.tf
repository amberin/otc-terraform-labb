resource "opentelekomcloud_networking_secgroup_v2" "kubernetes" {
  name        = "kubernetes"
  description = "kubernetes"
}

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

resource "opentelekomcloud_vpc_eip_v1" "cluster1" {
  publicip {
    type = "5_bgp"
  }
  bandwidth {
    name = "cluster1"
    size = 1
    share_type = "PER"
  }
}
resource "opentelekomcloud_vpc_eip_v1" "cluster1-worker1" {
  publicip {
    type = "5_bgp"
  }
  bandwidth {
    name = "cluster1-worker1"
    size = 1
    share_type = "PER"
  }
}


resource "opentelekomcloud_swr_organization_v2" "victororg" {
  name = "victororg"
}

resource "opentelekomcloud_cce_cluster_v3" "cluster1" {
  name                   = "cluster1"
  cluster_type           = "VirtualMachine"
  flavor_id              = "cce.s1.small"
  vpc_id                 = opentelekomcloud_vpc_v1.kubernetes.id
  subnet_id              = opentelekomcloud_vpc_subnet_v1.kubernetes.id
  container_network_type = "vpc-router"
  eip                    = opentelekomcloud_vpc_eip_v1.cluster1.publicip[0].ip_address
}

resource "opentelekomcloud_cce_node_v3" "cluster1-node1" {
  name              = "cluster1-node1"
  cluster_id        = opentelekomcloud_cce_cluster_v3.cluster1.id
  availability_zone = "eu-de-02"

  # Use the smallest possible worker node flavor in dev
  flavor_id = terraform.workspace == "prod" ? "s2.large.2" : "s2.large.2"
  # The specified SSH key pair will be authorized for login as the
  # user "linux".
  key_pair  = opentelekomcloud_compute_keypair_v2.victors.id

  eip_ids = [opentelekomcloud_vpc_eip_v1.cluster1-worker1.id]

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
