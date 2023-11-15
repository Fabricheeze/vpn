#Configure aws provider
provider "aws" {
  region = var.region
}

#Create a vpc
resource "aws_vpc" "new_vpc" {
  cidr_block = "172.168.0.0/16"

  tags = {
    Name = "fabalimi-new-vpc"
  }
}


#Create a public subnet
resource "aws_subnet" "public" {
  vpc_id     = aws_vpc.new_vpc.id
  cidr_block = "172.168.1.0/24"

  tags = {
    Name = var.subnet_name_public
  }
}

#Create a private subnet
resource "aws_subnet" "private" {
  vpc_id     = aws_vpc.new_vpc.id
  cidr_block = "172.168.2.0/24"

  tags = {
    Name = var.subnet_name_private
  }
}

#Create igw
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.new_vpc.id

  tags = {
    Name = var.igw_name
  }
}

#Create a security group
resource "aws_security_group" "allow_tls" {
  name        = "allow_tls"
  description = "Allow TLS inbound traffic"
  vpc_id      = aws_vpc.new_vpc.id

  ingress {
    description      = "TLS from VPC"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  ingress {
    description      = "TLS from VPC"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  ingress {
    description      = "TLS from VPC"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  ingress {
    description      = "TLS ICMP"
    from_port        = -1
    to_port          = -1
    protocol         = "icmp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  tags = {
    Name = "fabalimi_SecuGroup_new"
  }
}


#Create key pair

#Generer la clépriv�e RSA_4096� 
resource "tls_private_key" "private_key" {
    algorithm = "RSA"
    rsa_bits = 4096
}

#Create local_file to save the private key
resource "local_file" "key_file" {
    content=tls_private_key.private_key.private_key_pem
    filename = "/home/coder/work/Projets_VPN_automation_new/.ssh/fabalimi-aws-key.pem"
    directory_permission = "0600"
    file_permission = "0600"
}

#Create local_file to save the public key
resource "local_file" "public_key_file" {
    content=tls_private_key.private_key.public_key_openssh
    filename = "/home/coder/work/Projets_VPN_automation_new/.ssh/fabalimi-aws-key.pub"
    directory_permission = "0600"
    file_permission = "0600"
}

#Create key pair in aws
resource "aws_key_pair" "key_pair" {
  key_name = "fabalimi-private-key-new"
  public_key = tls_private_key.private_key.public_key_openssh
}

#Create an EC2 instance

data "aws_ami" "ubuntu" {
  most_recent = true
  owners = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-20211129"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}


resource "aws_instance" "this" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t2.nano"
  subnet_id     = aws_subnet.public.id
  key_name      = aws_key_pair.key_pair.key_name

  vpc_security_group_ids = [aws_security_group.allow_tls.id]

  associate_public_ip_address = true
  source_dest_check           = false

  tags = {
    Name = "fabalimi-vm2_new"
  }

  # Exécuter le playbook Ansible après la création de l'instance
 # provisioner "local-exec" {
 #   when    = create
 #   command = "ansible-playbook -i /home/coder/work/Projets_VPN_automation_new/ansible-nginx-config/inventory.ini /home/coder/work/Projets_VPN_automation_new/ansible-nginx-config/tasks/nginx-install.yaml"
 # }


  # Exécuter le playbook Ansible après la création de l'instance
  provisioner "local-exec" {
    when    = create
    command = <<-EOT
      echo '[webservers]' > /home/coder/work/Projets_VPN_automation_new/ansible-nginx-config/inventory.ini
      echo 'nginx ansible_host=${aws_instance.this.public_ip}' >> /home/coder/work/Projets_VPN_automation_new/ansible-nginx-config/inventory.ini
      echo '' >> /home/coder/work/Projets_VPN_automation_new/ansible-nginx-config/inventory.ini
      echo '[webservers:vars]' >> /home/coder/work/Projets_VPN_automation_new/ansible-nginx-config/inventory.ini
      echo 'ansible_ssh_private_key_file=${local_file.key_file.filename}' >> /home/coder/work/Projets_VPN_automation_new/ansible-nginx-config/inventory.ini
      echo 'ansible_user=ubuntu' >> /home/coder/work/Projets_VPN_automation_new/ansible-nginx-config/inventory.ini
      
      # Boucle d'attente active
      RETRIES=60
      DELAY=10
      COUNT=0
      echo "Attente pour l'instance AWS de devenir accessible via SSH..."
      until ssh -o "StrictHostKeyChecking=no" -i ${local_file.key_file.filename} ubuntu@${aws_instance.this.public_ip} "echo Instance is up" || [ $COUNT -eq $RETRIES ]; do
        sleep $DELAY
        COUNT=$((COUNT+1))
      done

      if [ $COUNT -eq $RETRIES ]; then
        echo "Timeout atteint en attendant l'instance AWS."
        exit 1
      fi

      ansible-playbook -i /home/coder/work/Projets_VPN_automation_new/ansible-nginx-config/inventory.ini /home/coder/work/Projets_VPN_automation_new/ansible-nginx-config/tasks/nginx-install.yaml
    EOT
  }
}

/*
#Create inventory.ini
resource "local_file" "inventory_file" {
  content = <<-DOC
    [webservers]
    nginx ansible_host=${aws_instance.this.public_ip}

    [webservers:vars]
    ansible_ssh_private_key_file=${local_file.key_file.filename}
    ansible_user=ubuntu
  DOC
  filename = "../ansible-nginx-config/inventory.ini"
}
*/


#Create a VPN gateway
resource "aws_vpn_gateway" "vpn_gw" {
  vpc_id = aws_vpc.new_vpc.id

  tags = {
    Name = "fabalimi_vpn_gw_new"
  }
}

# Create a Customer gateway
resource "aws_customer_gateway" "main" {
  bgp_asn    = 65000
  ip_address = var.customer_gateway_adress
  type       = "ipsec.1"

  tags = {
    Name = "fabalimi-strongswan-gateway_new"
  }
}

# Create aws_vpn_connection
resource "aws_vpn_connection" "main" {
	vpn_gateway_id      = aws_vpn_gateway.vpn_gw.id
	customer_gateway_id = aws_customer_gateway.main.id
	type                = "ipsec.1"
	static_routes_only  = true

    tags = {
    Name = "fabalimi_vpn_connection_new"
  }
}

#Create aws_vpn_connection_route
resource "aws_vpn_connection_route" "office" {
  destination_cidr_block = var.private_network_strongswan_adress
  vpn_connection_id      = aws_vpn_connection.main.id
}

#Create a route table
resource "aws_route_table" "route_table" {
  vpc_id = aws_vpc.new_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  route {
    cidr_block = var.private_network_strongswan_adress
    gateway_id = aws_vpn_gateway.vpn_gw.id
  } 

  tags = {
    Name = "fabalimi_rt_new"
  }
}

#Create a route table association

resource "aws_route_table_association" "public_subnet_association" {
  subnet_id = aws_subnet.public.id
  route_table_id = aws_route_table.route_table.id
}

resource "aws_route_table_association" "private_subnet_association" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.route_table.id
}

#Create aws_vpn_gateway_route_propagation
resource "aws_vpn_gateway_route_propagation" "propagation" {
  vpn_gateway_id = aws_vpn_gateway.vpn_gw.id
  route_table_id = aws_route_table.route_table.id
}

#Create "ansible_vars"
resource "local_file" "ansible_vars" {
  content = <<-DOC
    # Ansible vars_file containing variable values from Terraform.
    # Generated by Terraform mgmt configuration.

    strongswan_base: /etc
    ipsec_service: strongswan
    local_cidr: ${var.private_network_strongswan_adress}
    customer_gateway_address: ${aws_customer_gateway.main.ip_address}
    tunnel1_address: ${aws_vpn_connection.main.tunnel1_address}
    tunnel1_cgw_inside_address: ${aws_vpn_connection.main.tunnel1_cgw_inside_address}/30
    tunnel1_vgw_inside_address: ${aws_vpn_connection.main.tunnel1_vgw_inside_address}/30
    tunnel1_preshared_key: ${aws_vpn_connection.main.tunnel1_preshared_key}
    tunnel2_address: ${aws_vpn_connection.main.tunnel2_address}
    tunnel2_cgw_inside_address: ${aws_vpn_connection.main.tunnel2_cgw_inside_address}/30
    tunnel2_vgw_inside_address: ${aws_vpn_connection.main.tunnel2_vgw_inside_address}/30
    tunnel2_preshared_key: ${aws_vpn_connection.main.tunnel2_preshared_key}
    ec2_instance_ip: ${aws_instance.this.public_ip}
    private_key_path: "${local_file.key_file.filename}"
    vpc_cidr: ${aws_vpc.new_vpc.cidr_block}
    DOC
  filename = var.ansible_aws_vars_file
}

