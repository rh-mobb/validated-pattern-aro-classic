# Reserved sibling CIDRs are published for validated-pattern-openshift-virt.
# This root does not create NetApp or Route Server subnets.
locals {
  platform_cidrs = {
    vnet          = var.vnet_address_space
    control_plane = var.control_plane_subnet_prefix
    worker        = var.worker_subnet_prefix
    netapp        = var.netapp_subnet_prefix
    route_server  = var.route_server_subnet_prefix
  }

  route_server_prefix_length = tonumber(split("/", var.route_server_subnet_prefix)[1])

  platform_cidr_range = {
    for name, cidr in local.platform_cidrs : name => {
      start = (
        tonumber(split(".", cidrhost(cidr, 0))[0]) * 16777216 +
        tonumber(split(".", cidrhost(cidr, 0))[1]) * 65536 +
        tonumber(split(".", cidrhost(cidr, 0))[2]) * 256 +
        tonumber(split(".", cidrhost(cidr, 0))[3])
      )
      end = (
        tonumber(split(".", cidrhost(cidr, -1))[0]) * 16777216 +
        tonumber(split(".", cidrhost(cidr, -1))[1]) * 65536 +
        tonumber(split(".", cidrhost(cidr, -1))[2]) * 256 +
        tonumber(split(".", cidrhost(cidr, -1))[3])
      )
    }
  }
}

resource "terraform_data" "platform_cidrs" {
  lifecycle {
    precondition {
      condition = (
        local.platform_cidr_range.netapp.start >= local.platform_cidr_range.vnet.start &&
        local.platform_cidr_range.netapp.end <= local.platform_cidr_range.vnet.end
      )
      error_message = "netapp_subnet_prefix must be inside vnet_address_space."
    }

    precondition {
      condition = !(
        local.platform_cidr_range.worker.start <= local.platform_cidr_range.control_plane.end &&
        local.platform_cidr_range.control_plane.start <= local.platform_cidr_range.worker.end
      )
      error_message = "worker_subnet_prefix must not overlap control_plane_subnet_prefix."
    }

    precondition {
      condition = !(
        local.platform_cidr_range.netapp.start <= local.platform_cidr_range.worker.end &&
        local.platform_cidr_range.worker.start <= local.platform_cidr_range.netapp.end
      )
      error_message = "netapp_subnet_prefix must not overlap worker_subnet_prefix."
    }

    precondition {
      condition = !(
        local.platform_cidr_range.netapp.start <= local.platform_cidr_range.control_plane.end &&
        local.platform_cidr_range.control_plane.start <= local.platform_cidr_range.netapp.end
      )
      error_message = "netapp_subnet_prefix must not overlap control_plane_subnet_prefix."
    }

    precondition {
      condition = (
        local.platform_cidr_range.route_server.start >= local.platform_cidr_range.vnet.start &&
        local.platform_cidr_range.route_server.end <= local.platform_cidr_range.vnet.end
      )
      error_message = "route_server_subnet_prefix must be inside vnet_address_space."
    }

    precondition {
      condition = !(
        local.platform_cidr_range.route_server.start <= local.platform_cidr_range.control_plane.end &&
        local.platform_cidr_range.control_plane.start <= local.platform_cidr_range.route_server.end
      )
      error_message = "route_server_subnet_prefix must not overlap control_plane_subnet_prefix."
    }

    precondition {
      condition = !(
        local.platform_cidr_range.route_server.start <= local.platform_cidr_range.worker.end &&
        local.platform_cidr_range.worker.start <= local.platform_cidr_range.route_server.end
      )
      error_message = "route_server_subnet_prefix must not overlap worker_subnet_prefix."
    }

    precondition {
      condition = !(
        local.platform_cidr_range.route_server.start <= local.platform_cidr_range.netapp.end &&
        local.platform_cidr_range.netapp.start <= local.platform_cidr_range.route_server.end
      )
      error_message = "route_server_subnet_prefix must not overlap netapp_subnet_prefix."
    }

    precondition {
      condition     = local.route_server_prefix_length <= 26
      error_message = "route_server_subnet_prefix must be /26 or larger (Azure Route Server minimum)."
    }
  }
}
