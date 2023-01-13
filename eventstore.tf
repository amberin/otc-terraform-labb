resource "opentelekomcloud_vpc_v1" "victororg" {
  name = "victororg"
  cidr = "10.0.0.0/16"
}

locals {
  es_node_count = terraform.workspace == "prod" ? 3 : 3
  es_private_cluster_name = "cluster.eventstore.private"
}

resource "opentelekomcloud_vpc_subnet_v1" "eventstore" {
  name       = "eventstore"
  cidr       = "10.0.10.0/24"
  vpc_id     = opentelekomcloud_vpc_v1.victororg.id
  gateway_ip = "10.0.10.1"
  dns_list   = local.otc_dns_servers
}

resource "opentelekomcloud_networking_secgroup_v2" "eventstore" {
  name        = "eventstore"
  description = "eventstore"
}

resource "opentelekomcloud_networking_secgroup_rule_v2" "eventstore_internal" {
  description       = "Allow all traffic within the 'eventstore' security group"
  direction         = "ingress"
  ethertype         = "IPv4"
  remote_group_id   = opentelekomcloud_networking_secgroup_v2.eventstore.id
  security_group_id = opentelekomcloud_networking_secgroup_v2.eventstore.id
}

#resource "opentelekomcloud_networking_secgroup_rule_v2" "eventstore_from_kubernetes" {
#  description       = "Allow all traffic from Kubernetes cluster(s)"
#  direction         = "ingress"
#  ethertype         = "IPv4"
#  remote_group_id   = opentelekomcloud_networking_secgroup_v2.kubernetes.id
#  security_group_id = opentelekomcloud_networking_secgroup_v2.eventstore.id
#}

resource "opentelekomcloud_networking_secgroup_rule_v2" "eventstore_ping" {
  description       = "Allow ping from anywhere"
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "icmp"
  security_group_id = opentelekomcloud_networking_secgroup_v2.eventstore.id
}

resource "opentelekomcloud_networking_secgroup_rule_v2" "eventstore_trusted_sources" {
  for_each          = local.trusted_ips
  description       = "Allow all traffic from ${each.key}"
  direction         = "ingress"
  ethertype         = "IPv4"
  remote_ip_prefix  = each.value
  security_group_id = opentelekomcloud_networking_secgroup_v2.eventstore.id
}

# Temporary openings during migration from GCE
resource "opentelekomcloud_networking_secgroup_rule_v2" "eventstore_from_gce1" {
  description       = "Allow EventStore traffic from Google Cloud"
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 1113
  port_range_max    = 2113
  remote_ip_prefix  = "34.64.0.0/10"
  security_group_id = opentelekomcloud_networking_secgroup_v2.eventstore.id
}
resource "opentelekomcloud_networking_secgroup_rule_v2" "eventstore_from_gce2" {
  description       = "Allow EventStore traffic from Google Cloud"
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 1113
  port_range_max    = 2113
  remote_ip_prefix  = "35.224.0.0/12"
  security_group_id = opentelekomcloud_networking_secgroup_v2.eventstore.id
}

# Use a "server group" to ensure VMs run on different hypervisor hosts
resource "opentelekomcloud_compute_servergroup_v2" "eventstore" {
  name     = "eventstore"
  policies = ["anti-affinity"]
}

resource "opentelekomcloud_cbr_policy_v3" "eventstore_data" {
  name           = "eventstore_data"
  operation_type = "backup"
  operation_definition {
    retention_duration_days = terraform.workspace == "prod" ? 30 : 4
    timezone     = "UTC+02:00"
  }
  trigger_pattern = [
    # N.B. hour is specified in UTC; 19:00 means 21:00 Swedish time
    "FREQ=WEEKLY;BYDAY=MO,TU,WE,TH,FR;BYHOUR=19;BYMINUTE=00"
  ]
}
#resource "opentelekomcloud_cbr_vault_v3" "eventstore_data" {
#  name = "eventstore_data"
#  auto_bind = false
#  billing {
#    size          = terraform.workspace == "prod" ? 500 : 50 # TODO: Decide on proper backup space for prod
#    object_type   = "disk"
#    protect_type  = "backup"
#    charging_mode = "post_paid"
#  }
#  backup_policy_id = opentelekomcloud_cbr_policy_v3.eventstore_data.id
#  dynamic "resource" {
#    for_each = opentelekomcloud_blockstorage_volume_v2.eventstore_data[*]
#    content {
#      type = "OS::Cinder::Volume"
#      id   = resource.value["id"]
#    }
#  }
#}

## ES node data disks
#resource "opentelekomcloud_blockstorage_volume_v2" "eventstore_data" {
#  count       = local.es_node_count
#  name        = "eventstore_data_node${count.index + 1}"
#  volume_type = terraform.workspace == "prod" ? "SSD" : "SATA"
#  # Use 20 GB disk in prod, 10 GB in dev
#  size        = terraform.workspace == "prod" ? 20 : 10
#}
# ES node cloud user data
data "template_cloudinit_config" "eventstore" {
  part {
    content = <<-EOT
    #cloud-config
    ntp:
      servers:
        - ntp01.otc-service.com
        - ntp02.otc-service.com
    EOT
  }
  part {
    content = templatefile(
      "${path.module}/eventstore-node-setup.sh",
      {
        otc_access_key     = var.system_account_ak,
        otc_secret_key     = var.system_account_sk,
        otc_env            = terraform.workspace
        admin_pw           = var.eventstore_vm_admin_pw
        eventstore_version = "21.10.7"
        cluster_size       = local.es_node_count
        cluster_dns        = local.es_private_cluster_name
      }
    )
  }
}

# ES nodes
resource "opentelekomcloud_compute_instance_v2" "eventstore" {
  count               = local.es_node_count
  name                = "node${count.index + 1}.eventstore.private"
  image_name          = "Standard_Ubuntu_20.04_V100_latest"
  # In workspace "prod", allocate 4 GB RAM and some more bandwidth
  flavor_id           = terraform.workspace == "prod" ? "s3.medium.4" : "s2.medium.2"
  key_pair            = "victors"
  security_groups     = ["eventstore"]
  # Stop the OS gracefully before destroy, to increase the likelihood that the
  # data disk is left in a good state.
  stop_before_destroy = true 
  #availability_zone   = opentelekomcloud_cce_node_v3.cluster1-worker1.availability_zone
  network {
    uuid = opentelekomcloud_vpc_subnet_v1.eventstore.id
  }
  user_data = "${data.template_cloudinit_config.eventstore.rendered}"
  scheduler_hints {
    group = opentelekomcloud_compute_servergroup_v2.eventstore.id
  }
  lifecycle {
    ignore_changes = [
      user_data, # Because we often make tweaks to the user data script
      scheduler_hints, # Because these are missing from imported resources
    ]
  }
}
## Attach data disks to nodes
#resource "opentelekomcloud_compute_volume_attach_v2" "eventstore_data_attach" {
#  count       = local.es_node_count
#  volume_id   = opentelekomcloud_blockstorage_volume_v2.eventstore_data[count.index].id
#  instance_id = opentelekomcloud_compute_instance_v2.eventstore[count.index].id
#}
# All EventStore nodes need an elastic (public) IP
resource "opentelekomcloud_vpc_eip_v1" "eventstore" {
  count = local.es_node_count
  publicip {
    type = "5_bgp"
    port_id = opentelekomcloud_compute_instance_v2.eventstore[count.index].network[0].port
  }
  bandwidth {
    name = "minimal"
    size = 1
    share_type = "PER"
  }
}
# "node1.eventstore.private", "node2.eventstore.private" etc local DNS records
resource "opentelekomcloud_dns_recordset_v2" "eventstore_node" {
  count       = local.es_node_count
  zone_id     = opentelekomcloud_dns_zone_v2.private.id
  name        = "node${count.index + 1}.eventstore.private."
  ttl         = 300
  type        = "A"
  records     = [opentelekomcloud_compute_instance_v2.eventstore[count.index].access_ip_v4]
}
# Local DNS record for EventStore cluster
resource "opentelekomcloud_dns_recordset_v2" "eventstore_cluster" {
  zone_id     = opentelekomcloud_dns_zone_v2.private.id
  name        = "${local.es_private_cluster_name}."
  ttl         = 300
  type        = "A"
  records     = [for i in toset(range(local.es_node_count)) : opentelekomcloud_compute_instance_v2.eventstore[i].access_ip_v4]
}
