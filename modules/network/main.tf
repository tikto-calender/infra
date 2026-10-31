locals {
  az_count  = length(var.availability_zones)
  nat_count = var.nat_gateway_mode == "none" ? 0 : var.nat_gateway_mode == "single" ? 1 : local.az_count

  common_tags = merge(var.tags, {
    ManagedBy = "Terraform"
    Module    = "network"
  })

  public_kubernetes_tags = var.kubernetes_cluster_name == null ? {} : {
    "kubernetes.io/role/elb"                               = "1"
    "kubernetes.io/cluster/${var.kubernetes_cluster_name}" = "shared"
  }

  private_kubernetes_tags = var.kubernetes_cluster_name == null ? {} : {
    "kubernetes.io/role/internal-elb"                      = "1"
    "kubernetes.io/cluster/${var.kubernetes_cluster_name}" = "shared"
  }
}

resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(local.common_tags, {
    Name = "${var.name}-vpc"
  })
}

resource "aws_default_security_group" "this" {
  vpc_id = aws_vpc.this.id

  tags = merge(local.common_tags, {
    Name = "${var.name}-default-deny"
  })
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = merge(local.common_tags, {
    Name = "${var.name}-igw"
  })
}

resource "aws_subnet" "public" {
  for_each = {
    for index, az in var.availability_zones : az => {
      cidr = var.public_subnet_cidrs[index]
    }
  }

  vpc_id                  = aws_vpc.this.id
  availability_zone       = each.key
  cidr_block              = each.value.cidr
  map_public_ip_on_launch = false

  tags = merge(local.common_tags, local.public_kubernetes_tags, {
    Name = "${var.name}-public-${each.key}"
    Tier = "public"
  })
}

resource "aws_subnet" "private" {
  for_each = {
    for index, az in var.availability_zones : az => {
      cidr = var.private_subnet_cidrs[index]
    }
  }

  vpc_id                  = aws_vpc.this.id
  availability_zone       = each.key
  cidr_block              = each.value.cidr
  map_public_ip_on_launch = false

  tags = merge(local.common_tags, local.private_kubernetes_tags, {
    Name = "${var.name}-private-${each.key}"
    Tier = "private"
  })
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  tags = merge(local.common_tags, {
    Name = "${var.name}-public"
  })
}

resource "aws_route_table_association" "public" {
  for_each = aws_subnet.public

  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

resource "aws_eip" "nat" {
  count = local.nat_count

  domain = "vpc"

  depends_on = [aws_internet_gateway.this]

  tags = merge(local.common_tags, {
    Name = "${var.name}-nat-${count.index + 1}"
  })
}

resource "aws_nat_gateway" "this" {
  count = local.nat_count

  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[var.availability_zones[count.index]].id

  tags = merge(local.common_tags, {
    Name = "${var.name}-nat-${count.index + 1}"
  })
}

resource "aws_route_table" "private" {
  for_each = aws_subnet.private

  vpc_id = aws_vpc.this.id

  dynamic "route" {
    for_each = var.nat_gateway_mode == "none" ? [] : [1]
    content {
      cidr_block = "0.0.0.0/0"
      nat_gateway_id = var.nat_gateway_mode == "single" ? (
        aws_nat_gateway.this[0].id
        ) : (
        aws_nat_gateway.this[index(var.availability_zones, each.key)].id
      )
    }
  }

  tags = merge(local.common_tags, {
    Name = "${var.name}-private-${each.key}"
  })
}

resource "aws_route_table_association" "private" {
  for_each = aws_subnet.private

  subnet_id      = each.value.id
  route_table_id = aws_route_table.private[each.key].id
}

check "subnet_counts_match" {
  assert {
    condition = (
      length(var.public_subnet_cidrs) == local.az_count &&
      length(var.private_subnet_cidrs) == local.az_count
    )
    error_message = "Provide exactly one public and one private subnet CIDR for every availability zone."
  }
}
