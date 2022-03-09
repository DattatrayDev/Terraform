provider "aws" {
  region     = "ap-south-1"
}


########## create vpc ###############

resource "aws_vpc" "prod-vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "production"
  }
}

############ create internet gateway #############
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.prod-vpc.id
}


############# route table ##############
resource "aws_route_table" "prod-route-table" {
  vpc_id = aws_vpc.prod-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  route {
    ipv6_cidr_block        = "::/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "Prod"
  }
}

########### create subnet ###############
resource "aws_subnet" "subnet-1" {
  vpc_id     = aws_vpc.prod-vpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "ap-south-1a"

  tags = {
    Name = "Prod-Subnet"
  }
}

###########  associate subnet with route-table ##########

resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.subnet-1.id
  route_table_id = aws_route_table.prod-route-table.id
}

########## Security Group #############

resource "aws_security_group" "allow-web" {
  name        = "allow-web-traffic"
  description = "Allow web inbound traffic"
  vpc_id      = aws_vpc.prod-vpc.id

  ingress {
    description      = "HTTP"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  ingress {
    description      = "SSH"
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
    Name = "allow-web"
  }
}


############ network interface #########
resource "aws_network_interface" "web-server-NI" {
  subnet_id       = aws_subnet.subnet-1.id
  private_ips     = ["10.0.1.50"]
  security_groups = [aws_security_group.allow-web.id]

}

############# Elastic IP #########
resource "aws_eip" "one" {
  vpc                       = true
  network_interface         = aws_network_interface.web-server-NI.id
  associate_with_private_ip = "10.0.1.50"
  depends_on = [aws_internet_gateway.gw]
}


######## aws ec2 instance ##############

resource "aws_instance" "web-server-instance" {
  ami           = "ami-076754bea03bde973" # us-west-2
  instance_type = "t2.micro"
  # security_groups = [aws_security_group.security_group.name]
  availability_zone = "ap-south-1a"
  key_name = "Mumbai-KP"

  network_interface {
    device_index         = 0
    network_interface_id = aws_network_interface.web-server-NI.id
  }

    user_data =  <<-EOF
                 #!/bin/bash
                 sudo yum update -y
                 sudo amazon-linux-extras install docker
                 sudo service docker start
                 sudo docker run -p 80:80 -t dattatrayd/frontend-app:latest
                 EOF
}

