resource "opentelekomcloud_vpc_v1" "mysql" {
  name = "mysql"
  cidr = "10.20.0.0/24"
}

resource "opentelekomcloud_vpc_subnet_v1" "mysql" {
  name       = "mysql"
  cidr       = "10.20.0.0/24"
  vpc_id     = opentelekomcloud_vpc_v1.mysql.id
  gateway_ip = "10.20.0.1"
  dns_list   = local.otc_dns_servers
}

resource "opentelekomcloud_networking_secgroup_v2" "mysql" {
  name        = "mysql"
  description = "mysql"
}

resource "opentelekomcloud_rds_instance_v3" "mysql" {
  name              = "mysql"
  availability_zone = [opentelekomcloud_cce_node_v3.cluster1-worker1.availability_zone]

  db {
    password = var.mysql_root_pw
    type     = "MySQL"
    version  = "5.7"
  }

  security_group_id = opentelekomcloud_networking_secgroup_v2.mysql.id
  subnet_id         = opentelekomcloud_vpc_subnet_v1.mysql.id
  vpc_id            = opentelekomcloud_vpc_v1.mysql.id
  # Use the smallest possible machine size
  flavor            = "rds.mysql.c2.medium"

  volume {
    type = terraform.workspace == "prod" ? "ULTRAHIGH" : "COMMON"
    size = 40
  }

  backup_strategy {
    start_time = "23:00-00:00"
    keep_days  = 7
  }
}

resource "opentelekomcloud_dns_recordset_v2" "mysql" {
  zone_id     = opentelekomcloud_dns_zone_v2.private.id
  name        = "mysql.private."
  ttl         = 600
  type        = "A"
  records     = opentelekomcloud_rds_instance_v3.mysql.private_ips
}

resource "opentelekomcloud_networking_secgroup_rule_v2" "mysql_ping" {
  description       = "Allow ping from anywhere"
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "icmp"
  security_group_id = opentelekomcloud_networking_secgroup_v2.mysql.id
}

resource "opentelekomcloud_networking_secgroup_rule_v2" "mysql_trusted_sources" {
  for_each          = local.trusted_ips
  description       = "Allow MySQL traffic from ${each.key}"
  direction         = "ingress"
  ethertype         = "IPv4"
  port_range_max    = 3306
  port_range_min    = 3306
  protocol          = "tcp"
  remote_ip_prefix  = each.value
  security_group_id = opentelekomcloud_networking_secgroup_v2.mysql.id
}

# Temporary openings during migration from GCE
resource "opentelekomcloud_networking_secgroup_rule_v2" "mysql_from_gce1" {
  description       = "Allow MySQL traffic from Google Cloud"
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 3306
  port_range_max    = 3306
  remote_ip_prefix  = "34.64.0.0/10"
  security_group_id = opentelekomcloud_networking_secgroup_v2.mysql.id
}
resource "opentelekomcloud_networking_secgroup_rule_v2" "mysql_from_gce2" {
  description       = "Allow MySQL traffic from Google Cloud"
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 3306
  port_range_max    = 3306
  remote_ip_prefix  = "35.224.0.0/12"
  security_group_id = opentelekomcloud_networking_secgroup_v2.mysql.id
}

resource "opentelekomcloud_networking_secgroup_rule_v2" "mysql_from_kubernetes" {
  description       = "Allow all traffic from Kubernetes cluster(s)"
  direction         = "ingress"
  ethertype         = "IPv4"
  remote_group_id   = opentelekomcloud_networking_secgroup_v2.kubernetes.id
  security_group_id = opentelekomcloud_networking_secgroup_v2.mysql.id
}
