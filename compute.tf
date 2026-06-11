# ==============================================================================
# BLOCK 1: DYNAMIC OPERATING SYSTEM IMAGE QUERY
# ==============================================================================
# Dynamic look up for the latest verified vanilla Windows Server 2022 base image.
data "aws_ami" "windows_2022" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["Windows_Server-2022-English-Full-Base-*"]
  }
}

# ==============================================================================
# BLOCK 2: SECURE ADMINISTRATIVE ACCESS KEYS
# ==============================================================================
# Registers your public encryption key with AWS for secure administrative logging.
resource "aws_key_pair" "deployer" {
  key_name   = "p46-range-admin-key"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQ..." # REMEMBER: Paste your local terminal public key string here
}

# ==============================================================================
# BLOCK 3: VIRTUAL MACHINE INSTANCE PROVISIONING
# ==============================================================================

# IDENTITY ASSET 01: PRIMARY DOMAIN CONTROLLER
resource "aws_instance" "dc01" {
  ami                    = data.aws_ami.windows_2022.id
  instance_type          = "t3.large" # 2 vCPUs, 8 GB RAM
  subnet_id              = aws_subnet.corp_za.id
  vpc_security_group_ids = [aws_security_group.internal_lan.id]
  key_name               = aws_key_pair.deployer.key_name

  tags = {
    Name         = "p46-aws-dc01"
    AnsibleGroup = "domain_controllers" 
    ADRole       = "Primary-Forest-Root"
  }
}

# IDENTITY ASSET 02: SECONDARY REPLICATED DOMAIN CONTROLLER
resource "aws_instance" "dc02" {
  ami                    = data.aws_ami.windows_2022.id
  instance_type          = "t3.large" # 2 vCPUs, 8 GB RAM
  subnet_id              = aws_subnet.corp_zb.id
  vpc_security_group_ids = [aws_security_group.internal_lan.id]
  key_name               = aws_key_pair.deployer.key_name

  tags = {
    Name         = "p46-aws-dc02"
    AnsibleGroup = "domain_controllers"
    ADRole       = "Replica-Node"
  }
}

# DATA WORKLOAD ASSET: SQL SERVER
resource "aws_instance" "sql01" {
  ami                    = data.aws_ami.windows_2022.id
  instance_type          = "t3.xlarge" # 4 vCPUs, 16 GB RAM (Meets your minimum 4-core requirement)
  subnet_id              = aws_subnet.app_zone.id
  vpc_security_group_ids = [aws_security_group.internal_lan.id]
  key_name               = aws_key_pair.deployer.key_name

  tags = {
    Name         = "p46-aws-sql01"
    AnsibleGroup = "database_servers"
  }
}

# APPLICATION PRESENTATION ASSET: IIS WEB SERVER
resource "aws_instance" "iis01" {
  ami                    = data.aws_ami.windows_2022.id
  instance_type          = "t3.xlarge" # 4 vCPUs, 16 GB RAM (Meets your minimum 4-core requirement)
  subnet_id              = aws_subnet.app_zone.id
  vpc_security_group_ids = [aws_security_group.internal_lan.id]
  key_name               = aws_key_pair.deployer.key_name

  tags = {
    Name         = "p46-aws-iis01"
    AnsibleGroup = "web_servers"
  }
}