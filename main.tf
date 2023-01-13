terraform {
  required_providers {
    opentelekomcloud = {
      source = "opentelekomcloud/opentelekomcloud"
      version = "1.31.3"
    }
    template = {
      source = "hashicorp/template"
      version = "2.2.0"
    }
  }
  backend "s3" {
    endpoint                    = "obs.eu-de.otc.t-systems.com"
    region                      = "eu-de"
    bucket                      = "victortfstate" # name of OBS bucket
    key                         = "statefile"      # statefile filename in OBS bucket
    skip_region_validation      = true
    skip_credentials_validation = true
  }
}

provider "opentelekomcloud" {
  user_name   = var.my_username
  access_key  = var.my_access_key
  secret_key  = var.my_secret_key
  # tenant_name = project name (renamed in the v3 API)
  tenant_name = "${local.otc_region}_${terraform.workspace}"
  auth_url    = "https://iam.eu-de.otc.t-systems.com/v3"
}

# Set some local constants
locals {
  otc_region = "eu-de"
  # These DNS servers are required when using private DNS zones.
  otc_dns_servers = [
    "100.125.4.25",
    "100.125.129.199",
  ]
  trusted_ips = {
    "MG home"   = "80.216.233.111/32"
    "MG office" = "194.237.228.158/32"
    "VA home"   = "213.163.152.245/32"
  }
}

# Create private DNS zone for use by all VPCs/subnets
resource "opentelekomcloud_dns_zone_v2" "private" {
  type  = "private"
  name  = "private."
  email = "victor.andreasson@b3.se"
  ttl   = 300
  router {
    router_id = opentelekomcloud_vpc_v1.victororg.id
    router_region = local.otc_region
  }
}

resource "opentelekomcloud_compute_keypair_v2" "victors" {
  name        = "victors"
  public_key  = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQCXU4hFdhzHIKiCXrHcbnPwweYIbed6TPOAj7C71yl0oETyicpivxMBYFOJLbMiEBqURChvYx645nezzd2B0eY+o+hW+A5I99tjkW3MJKBzRM3b+yi+uDHV1ovpkGXcMBF3r/FLhHeSEiURJcVJxnpbUXZ+IoCd8rdaUPaIj3NvyIZuKeHkiEv9pNJaLLa8uTPYNAS0E9TADiWwf55eGsZAJnaxEXixx18JOtQ9aJfdWn6tl97DSDToDTZPbhMMpSnUKQjDSHCbygiY3qRtLn8E+//DNOuzAxCS6S9nUarLP7/MwnZfFPn7Nrs4BcRauhhk9OM+p3C6JjYmYa9d+YVWXNBFA7mBs0gt5Vc58E3J58rCO0uDIFRRzEp/+g6bnfDi37CgEWMMDRXpnyDoLTE0qTEqRdlKEvW1+ZlMG7HSo9qJBYocEYS3oLfdgiucdhBEcEL/uIZTwudwFWkWRnUkDD4cRafAPUXVgOIH+vPbHWqZv8SE/r3lZd4orswyGlhVozSsAac9yMAlu9aAzSYjPyN78QcMILF/xyR/WvsczArh75ntoNbbYVWySXkJVfVK4r9WPt043J+UpvKSICIkhIONZeHTeXaCTnO/Iz3UTbzmz0Us5UmwV8G6RwGywlLdhgwZDEHxo+BWmi0ICgskx1MG8gcslj/tD0fJrGrxKQ== cardno:000609611367"
  region      = local.otc_region
}
