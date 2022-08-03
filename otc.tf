terraform {
  required_providers {
    opentelekomcloud = {
      source = "opentelekomcloud/opentelekomcloud"
      version = "1.30.2"
    }
  }
  backend "s3" {
    endpoint                    = "obs.eu-de.otc.t-systems.com"
    region                      = "eu-de"
    bucket                      = "victortfstate" # name of OBS bucket
    key                         = "statefile"     # statefile filename in OBS bucket
    skip_region_validation      = true
    skip_credentials_validation = true
  }
}

provider "opentelekomcloud" {
  user_name   = "terraform-${terraform.workspace}"
  access_key  = var.otc_access_key
  secret_key  = var.otc_secret_key
  # tenant_name = project name (renamed in the v3 API)
  tenant_name = "eu-de_${terraform.workspace}"
  auth_url    = "https://iam.eu-de.otc.t-systems.com/v3"
}

resource "opentelekomcloud_vpc_v1" "network_1" {
  name = "network_1"
  cidr = "10.0.0.0/24"
}

resource "opentelekomcloud_vpc_subnet_v1" "subnet_1" {
  name       = "subnet_1"
  cidr       = "10.0.0.0/24"
  vpc_id     = opentelekomcloud_vpc_v1.network_1.id
  gateway_ip = "10.0.0.1"
}

resource "opentelekomcloud_cce_cluster_v3" "cluster1" {
  name        = "cluster1"
  description = "My toy cluster"

  cluster_type           = "VirtualMachine"
  flavor_id              = "cce.s1.small"
  vpc_id                 = opentelekomcloud_vpc_v1.network_1.id
  subnet_id              = opentelekomcloud_vpc_subnet_v1.subnet_1.id
  container_network_type = "overlay_l2"
}

# Add a SSH public key to the region. Primarily because we must
# specify an authorized key pair when creating CCE nodes. N.B: For
# some reason, this imported key is not visible in the OTC web console
# -- but it does work.
resource "opentelekomcloud_compute_keypair_v2" "victors" {
  name        = "victors"
  public_key  = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQCXU4hFdhzHIKiCXrHcbnPwweYIbed6TPOAj7C71yl0oETyicpivxMBYFOJLbMiEBqURChvYx645nezzd2B0eY+o+hW+A5I99tjkW3MJKBzRM3b+yi+uDHV1ovpkGXcMBF3r/FLhHeSEiURJcVJxnpbUXZ+IoCd8rdaUPaIj3NvyIZuKeHkiEv9pNJaLLa8uTPYNAS0E9TADiWwf55eGsZAJnaxEXixx18JOtQ9aJfdWn6tl97DSDToDTZPbhMMpSnUKQjDSHCbygiY3qRtLn8E+//DNOuzAxCS6S9nUarLP7/MwnZfFPn7Nrs4BcRauhhk9OM+p3C6JjYmYa9d+YVWXNBFA7mBs0gt5Vc58E3J58rCO0uDIFRRzEp/+g6bnfDi37CgEWMMDRXpnyDoLTE0qTEqRdlKEvW1+ZlMG7HSo9qJBYocEYS3oLfdgiucdhBEcEL/uIZTwudwFWkWRnUkDD4cRafAPUXVgOIH+vPbHWqZv8SE/r3lZd4orswyGlhVozSsAac9yMAlu9aAzSYjPyN78QcMILF/xyR/WvsczArh75ntoNbbYVWySXkJVfVK4r9WPt043J+UpvKSICIkhIONZeHTeXaCTnO/Iz3UTbzmz0Us5UmwV8G6RwGywlLdhgwZDEHxo+BWmi0ICgskx1MG8gcslj/tD0fJrGrxKQ== cardno:000609611367"
  region      = "eu-de"
}

resource "opentelekomcloud_cce_node_v3" "node1" {
  name              = "node1"
  cluster_id        = opentelekomcloud_cce_cluster_v3.cluster1.id
  availability_zone = "eu-de-02"

  flavor_id = "s2.large.2"
  # The specified SSH key pair will be authorized for login as the
  # user "linux".
  key_pair  = opentelekomcloud_compute_keypair_v2.victors.id

  bandwidth_size = 100

  root_volume {
    size       = 40
    volumetype = "SATA"
  }

  data_volumes {
    size       = 100
    volumetype = "SATA"
  }
}
