# ==============================================================================
# BLOCK 1: VIRTUAL PRIVATE CLOUD (VPC) CREATION
# ==============================================================================
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16" # Provides 65,536 private IP addresses (10.0.0.0 to 10.0.255.255)
  enable_dns_hostnames = true          # Required for Windows Active Directory domain resolution
  enable_dns_support   = true          # Allows AWS to handle internal DNS queries smoothly

  tags = { Name = "p46-primary-vpc" }
}

# ==============================================================================
# BLOCK 2: SUBNET DESIGNATION (NETWORK SEGREGATION)
# ==============================================================================
# Subnet for Domain Controller 01 (Availability Zone A)
resource "aws_subnet" "corp_za" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.1.0/24" # Provides 254 static IPs (10.0.1.x)
  availability_zone = "us-east-1a"
  tags              = { Name = "p46-corp-subnet-azA" }
}

# Subnet for Domain Controller 02 (Availability Zone B)
resource "aws_subnet" "corp_zb" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.2.0/24" # Provides 254 static IPs (10.0.2.x)
  availability_zone = "us-east-1b"
  tags              = { Name = "p46-corp-subnet-azB" }
}

# Subnet for high-performance application assets (SQL and IIS)
resource "aws_subnet" "app_zone" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.10.0/24" # Provides 254 static IPs (10.0.10.x)
  availability_zone = "us-east-1a"
  tags              = { Name = "p46-app-subnet" }
}

# ==============================================================================
# BLOCK 3: FIREWALL DESIGN (SECURITY GROUPS)
# ==============================================================================
resource "aws_security_group" "internal_lan" {
  name        = "p46-internal-security-rules"
  description = "Allow strict internal enterprise traffic communication channels"
  vpc_id      = aws_vpc.main.id

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