# ==============================================================================
# BLOCK 1: VIRTUAL PRIVATE CLOUD (VPC) CREATION & ROUTING
# ==============================================================================
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16" # Provides 65,536 private IP addresses (10.0.0.0 to 10.0.255.255)
  enable_dns_hostnames = true          # Required for Windows Active Directory domain resolution
  enable_dns_support   = true          # Allows AWS to handle internal DNS queries smoothly

  tags = { Name = "p46-primary-vpc" }
}

# Internet Gateway to bridge your private AWS network to the public internet
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "p46-internet-gateway" }
}

# Route Table directing external traffic out to the Internet Gateway
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = { Name = "p46-public-route-table" }
}

# ==============================================================================
# BLOCK 2: SUBNET DESIGNATION (NETWORK SEGREGATION)
# ==============================================================================
# Subnet for Domain Controller 01 (Availability Zone A)
resource "aws_subnet" "corp_za" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24" # Provides 254 static IPs (10.0.1.x)
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true          # Automatically assigns a public IP to instances
  tags                    = { Name = "p46-corp-subnet-azA" }
}

# Subnet for Domain Controller 02 (Availability Zone B)
resource "aws_subnet" "corp_zb" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24" # Provides 254 static IPs (10.0.2.x)
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true          # Automatically assigns a public IP to instances
  tags                    = { Name = "p46-corp-subnet-azB" }
}

# Subnet for high-performance application assets (SQL and IIS)
resource "aws_subnet" "app_zone" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.10.0/24" # Provides 254 static IPs (10.0.10.x)
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true           # Automatically assigns a public IP to instances
  tags                    = { Name = "p46-app-subnet" }
}

# Associate Subnets to the Public Route Table so they have internet paths
resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.corp_za.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "b" {
  subnet_id      = aws_subnet.corp_zb.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "c" {
  subnet_id      = aws_subnet.app_zone.id
  route_table_id = aws_route_table.public_rt.id
}

# ==============================================================================
# BLOCK 3: FIREWALL DESIGN (SECURITY GROUPS)
# ==============================================================================
resource "aws_security_group" "internal_lan" {
  name        = "p46-internal-security-rules"
  description = "Allow strict internal enterprise traffic communication channels"
  vpc_id      = aws_vpc.main.id

  # Inbound Security Rule to allow Remote Desktop (RDP) from the outside
  ingress {
    from_port   = 3389
    to_port     = 3389
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Inbound Security Rules: Allows completely unhindered communication BETWEEN 
  # servers inside our private network fence so they can replicate AD information.
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1" # Allows all protocols internally
    cidr_blocks = ["10.0.0.0/16"] 
  }

  # Outbound Security Rules: Allows your servers to talk out to the public internet
  # so they can pull system updates and patches.
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"] # Anywhere on the internet
  }
}

# ==============================================================================
# BLOCK 4: AWS SITE-TO-SITE VPN INFRASTRUCTURE
# ==============================================================================

# 1. Create the AWS Virtual Private Gateway (VGW) - The AWS Border Router
resource "aws_vpn_gateway" "vpn_gw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "p46-aws-vpngw"
  }
}

# 2. Attach the VGW to the VPC's main Route Table
# This tells the AWS network: "If you need to reach Azure (10.1.x.x), go to the VGW"
resource "aws_route" "vpn_route" {
  route_table_id         = aws_route_table.public_rt.id
  destination_cidr_block = "10.1.0.0/16" # Azure's VNet IP space
  gateway_id             = aws_vpn_gateway.vpn_gw.id
}

# 3. Create the Customer Gateway (CGW) - Represents Azure inside AWS
resource "aws_customer_gateway" "azure_cgw" {
  bgp_asn    = 65000
  ip_address = "40.121.127.56" # The Public IP from Azure we just waited for!
  type       = "ipsec.1"

  tags = {
    Name = "p46-azure-cgw"
  }
}

# 4. Create the IPsec VPN Tunnel Connection
resource "aws_vpn_connection" "main" {
  vpn_gateway_id      = aws_vpn_gateway.vpn_gw.id
  customer_gateway_id = aws_customer_gateway.azure_cgw.id
  type                = "ipsec.1"
  static_routes_only  = true # We will use static routing for this hybrid lab

  # Provide the highly secure pre-shared key (password) for Tunnel 1
  tunnel1_preshared_key = "P46_HybridCloud_Tunnel_2026" # Fixed to meet AWS character constraints

  tags = {
    Name = "p46-aws-to-azure-vpn"
  }
}

# 5. Define the Static Route inside the VPN Connection
resource "aws_vpn_connection_route" "azure_network" {
  destination_cidr_block = "10.1.0.0/16"
  vpn_connection_id      = aws_vpn_connection.main.id
}