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
  key_name   = "p46-range-admin-key-v3"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDaEf0eRAxJc/Tlsv6oDRKQxUFYpBRXoLhPcihPGvolZHr5aHXRaUehUH5O7iUj3Ia3DxJsqFeUa2tFe65amKow+BKkLB7t/l0fLvsZSdIzWkHT79XlFc7WuPlPGaX9mRy7tIDpfBOVNozJpsBhNkIIP79cR3GKZ4rPFl3ddMg/mh94q3+460fDr7IeHmYARM988FEAD7GWKcTeUCDTzrScFpCaKR20hhMTaCHO3Zoy43qYJkmpwdRM6F+TpMhm4wQxDJ73iIG+iJrRmQwpQL/d6MY+ZBvQSNa5PduYSVFe7L895AbHNXDlIdqUCHuxXbT/DgFkqGy44Hhkan95vpdJ4afuh3Hsua0O4Z8UeevRUhhIOTGl3DklvUlgT+85SJbNk+ruUdsgglKhOqKm4X84033AtYF9NZERYUF+q10Zq7hUK2x24jbYGNuD41Ft8OxKaDrWv16nifdYOb7ByN5ocdK0+IqKu2UK5sBUOrsm5tXPPe/nG+wuSbC8y9jHvVE2pjyJhtaEdp+xlVLPrRzWM/JQXqkzkaC4+/dCNtenT0kaKBZasOCFLk3PLO2Y/KGVTk8TWAPwM/qMtv0rgos966/DBQJoSPWlKZmGYVMsmC6/DJXR1DfKlOr+ySJ8aXlBZ/Wc7VKKKgzK8eMLiKBQrn9ELmK2vDT8ixfrzXQvfw== antarpreetsingh@Antarpreets-MacBook-Pro-2.local" # REMEMBER: Paste your local terminal public key string here
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