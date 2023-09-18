# Virtual Private Cloud (VPC). A VPC is a virtual network that enables you to launch AWS resources into a virtual network that you define 
resource "aws_vpc" "main" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"

  tags = {
    Name = "main"
  }
}

# subnet is a logical subdivision of an IP network.It further divides a VPC into multiple small networks so that they can be managed seperately.
resource "aws_subnet" "public_subnet" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "${var.region}a" 
  #map_public_ip_on_launch = true -- provide internet access to instances in a subnet, may come with higher cost and dynamic IPs. (a better option is eip) 

  tags = {
    Name = "public_subnet"
  }
}

resource "aws_subnet" "private_subnet" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.0.2.0/24"
  availability_zone = "${var.region}a" 

  tags = {
    Name = "private_subnet"
  }
}

# Internet Gateway allows communication between your VPC and the internet. Only one IGW can be attached to one VPC and vice-versa.
resource "aws_internet_gateway" "gateway" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "gateway"
  }
}

#route table contains a set of rules, called routes, that are used to determine where network traffic from your subnet or gateway is directed.
resource "aws_route_table" "route" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gateway.id
  }

  tags = {
    Name = "route"
  }
}

# Internet gateway itself doesn’t provide access to the internet, Route table must be associated with the subnets and routes should be defined.
resource "aws_route_table_association" "route_associate" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.route.id
}

# Private Route Table
resource "aws_route_table" "private_route_table" {
  vpc_id = aws_vpc.main.id
}

# Associate the Private Route Table with the Private Subnet
resource "aws_route_table_association" "private_subnet_association" {
  subnet_id      = aws_subnet.private_subnet.id
  route_table_id = aws_route_table.private_route_table.id
}

# A security group acts as a virtual firewall for your EC2 instances to control incoming and outgoing traffic.
# NACL operates at the subnet level, which means it controls traffic in and out of all resources within a subnet --stateless
# Security Groups operate at the instance level. Each EC2 instance can have one or more security groups associated with it -- statefull (inbound rule will autumatically apply outbound)
resource "aws_security_group" "allow_web" {
  name        = "allow_web"
  description = "Allow WEB inbound traffic"
  vpc_id      = aws_vpc.main.id

  ingress {
    description      = "WEB"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }
  ingress {
    description      = "WEB"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }
  ingress {
    description      = "WEB"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow_web"
  }
}

resource "aws_security_group" "allow_private" {
  name        = "allow_private"
  description = "Allow private inbound traffic"
  vpc_id      = aws_vpc.main.id

  ingress {
    description      = "private"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]

  }


  tags = {
    Name = "allow_private"
  }
}

# A network interface is a virtual network card that allows a computing device to connect to a network, enabling it to send and receive data over that network.
resource "aws_network_interface" "web-server-nic" {
  subnet_id       = aws_subnet.public_subnet.id
  private_ips     = ["10.0.1.50"]
  security_groups = [aws_security_group.allow_web.id]
}

resource "aws_network_interface" "private-server-nic" {
  subnet_id       = aws_subnet.private_subnet.id
  private_ips     = ["10.0.2.50"]
  security_groups = [aws_security_group.allow_private.id]
}

# An AWS Elastic IP (EIP) is a static, public IPv4 address that can be dynamically associated with an Amazon EC2 instance, providing a persistent IP for your AWS resources.
resource "aws_eip" "web-ip" {
  domain                    = "vpc"
  instance                  = aws_instance.web-instance.id
  network_interface         = aws_network_interface.web-server-nic.id
  associate_with_private_ip = aws_instance.web-instance.private_ip
  depends_on = [ aws_internet_gateway.gateway ]

}

# cryptographic key used for encrypting and decrypting data in secure communication 
resource "tls_private_key" "web_ssh" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# secure key pair consisting of a public key and a private key used for secure SSH access to Amazon EC2 instances, providing authentication and security.
resource "aws_key_pair" "web-key" {
  key_name   = "web-key"
  public_key = tls_private_key.web_ssh.public_key_openssh
}

resource "local_file" "web_key" {
  filename = "${path.module}\\web_key.pem"
  content = tls_private_key.web_ssh.private_key_pem
}

resource "tls_private_key" "private_ssh" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "private-key" {
  key_name   = "private-key"
  public_key = tls_private_key.private_ssh.public_key_openssh
  
}

resource "local_file" "private_key" {
  filename = "${path.module}\\private_key.pem"
  content = tls_private_key.private_ssh.private_key_pem
}


resource "aws_instance" "web-instance" {
  ami           = "ami-053b0d53c279acc90"
  instance_type = "t2.micro"
  subnet_id = aws_subnet.public_subnet.id
  key_name = aws_key_pair.web-key.key_name
  
  user_data = <<-EOF
              #!/bin/bash
              sudo apt update -y 
              sudo apt install apache2 -y 
              sudo systemctl start apache2 
              sudo bash -c 'echo welcome to my website > var/www/html/index.html'
              EOF

  tags = {
    Name = "web-instance"
  }
}

resource "aws_network_interface_sg_attachment" "web_sg_attachment" {
  security_group_id    = aws_security_group.allow_web.id
  network_interface_id = aws_instance.web-instance.primary_network_interface_id
}

# there are a lot of usecases where your instances in private subnet needs access to the internet This can be done securely using NAT Gateway which allows instances in the private subnet to connect to the internet via a secure route.
resource "aws_instance" "private-instance" {
  ami           = "ami-053b0d53c279acc90"
  instance_type = "t2.micro"
  subnet_id = aws_subnet.private_subnet.id
  key_name = aws_key_pair.private-key.id
  
  tags = {
    Name = "private-instance"
  }
}

resource "aws_network_interface_sg_attachment" "private_sg_attachment" {
  security_group_id    = aws_security_group.allow_private.id
  network_interface_id = aws_instance.private-instance.primary_network_interface_id
}
