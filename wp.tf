provider "aws" {
region = "ap-south-1"
profile = "pushkar1"
}
variable "mykey" {
	type = string
	default = "mykey121"
}

//creating VPC
resource "aws_vpc" "myvpc1" {
  cidr_block = "192.168.0.0/16"
  enable_dns_hostnames = "true"

  tags = {
    Name = "MyVpc"
  }
}
//Creating Public Subnet
resource "aws_subnet" "public_subnet" {
  depends_on = [
    aws_vpc.myvpc1,
  ]
  vpc_id     = aws_vpc.myvpc1.id
  cidr_block = "192.168.2.0/24"
  availability_zone = "ap-south-1a"
  map_public_ip_on_launch = "true"

  tags = {
    Name = "Public Subnet"
  }
}
//Creating Private Subnet
resource "aws_subnet" "private_subnet" {
  depends_on = [
    aws_vpc.myvpc1,
  ]
  vpc_id     = aws_vpc.myvpc1.id
  cidr_block = "192.168.1.0/24"
  availability_zone = "ap-south-1b"

  tags = {
    Name = "Private Subnet"
  }
}
//Creating Internet Gateway for outside Connection
resource "aws_internet_gateway" "gw" {
  depends_on = [
    aws_vpc.myvpc1,
  ]
  vpc_id = aws_vpc.myvpc1.id

  tags = {
    Name = "Internet gateway"
  }
}

//Creating Route table
resource "aws_route_table" "my_route_table1" {
  depends_on = [
    aws_vpc.myvpc1,
  ]
  vpc_id = aws_vpc.myvpc1.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  
  tags = {
    Name = "Routing Table"
  }
}
//table association
resource "aws_route_table_association" "Route_association" {
  depends_on = [
    aws_route_table.my_route_table1,
  ]
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.my_route_table1.id
}

//Creating Elastic IP
resource "aws_eip" "myeip" {

  vpc      = true

  depends_on = [aws_internet_gateway.gw,]

}
//Creating NAT Gateway
resource "aws_nat_gateway" "nat_gateway" {

  depends_on = [aws_vpc.myvpc1]

  allocation_id = aws_eip.myeip.id

  subnet_id     = aws_subnet.public_subnet.id

  tags = {

    Name = "nat gateway"

    }

}

// Create Routing Table for NGW

resource "aws_route_table" "nat_routing_table" {

    depends_on = [aws_vpc.myvpc1]

    vpc_id = aws_vpc.myvpc1.id

    route {

    cidr_block = "0.0.0.0/0"

    nat_gateway_id = aws_nat_gateway.nat_gateway.id

  }

    tags = {

        Name = "nat routing table"

    }

}

//AWS_Route_Table_Association for NAT Gateway

resource "aws_route_table_association" "nat_route_asction" {

    depends_on = [ aws_subnet.private_subnet, aws_nat_gateway.nat_gateway ]

    subnet_id = aws_subnet.private_subnet.id

    route_table_id = aws_route_table.nat_routing_table.id

}

//Creating Security group for Wordpress
resource "aws_security_group" "Wordpress_sg" {

  name        = "Wordpress_sg"
  description = "Allow Tcp $ Ssh inbound traffic"
  vpc_id      = aws_vpc.myvpc1.id
  

  # ingress {
  #   description = "Ssh"
  #   from_port   = 22
  #   to_port     = 22
  #   protocol    = "tcp"
  #   cidr_blocks = ["0.0.0.0/0"]
  # }
 ingress {
    description = "http"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow_SSh_http"
  }
}
//Creating Security groups for MySql
resource "aws_security_group" "MySql_sg" {
  name        = "MySq_sg"
  description = "Allow Wordpress inbound traffic"
  vpc_id      = aws_vpc.myvpc1.id
  

  
 ingress {
    description = "Allow MySql"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
 ingress {
    description = "Ssh"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow_MySql"
  }
}
//creating Bastion Host Security groups
resource "aws_security_group" "Bastion_host_sg" {

  name        = "Bastion_host_sg"
  description = "Allow Tcp $ Ssh inbound traffic"
  vpc_id      = aws_vpc.myvpc1.id
  

  ingress {
    description = "Ssh"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
 

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow_SSh"
  }
}

//Creating AWS instance for MySql
resource "aws_instance" "mysql"{
   depends_on = [
    aws_vpc.myvpc1,aws_security_group.MySql_sg,aws_route_table_association.nat_route_asction,
  ]
ami   = "ami-0e306788ff2473ccb"
instance_type = "t2.micro"
vpc_security_group_ids = [ aws_security_group.MySql_sg.id]
subnet_id = aws_subnet.private_subnet.id
user_data = <<-EOF
#!/bin/bash
sudo yum update -y
sudo yum install docker -y
sudo systemctl start docker
sudo systemctl enable docker
sudo su root
docker run -dit -p 80:3306 --name mysql -e MYSQL_ROOT_PASSWORD=pushkar121 -e MYSQL_DATABASE=DB -e MYSQL_USER=pushkar -e MYSQL_PASSWORD=redhat mysql:5.6
EOF
tags = {
 Name = "MySqlOS"
  }
} 


//Creating aws instance for Wordpress
resource "aws_instance" "webpage"{
  depends_on = [
    aws_vpc.myvpc1,aws_security_group.Wordpress_sg,
  ]
ami   = "ami-0e306788ff2473ccb"
instance_type = "t2.micro"
associate_public_ip_address = "true"
availability_zone = "ap-south-1a"
key_name = var.mykey
vpc_security_group_ids = [ aws_security_group.Wordpress_sg.id]
subnet_id = aws_subnet.public_subnet.id
user_data = <<-EOF
#!/bin/bash
sudo yum update -y
sudo yum install docker -y
sudo systemctl start docker
sudo systemctl enable docker
sudo su root
docker run -dit -p 80:80 --name wp wordpress:4.8-apache
EOF
tags = {
 Name = "wpOS"
  }
} 

//Creating Bastion host for maintainence 

resource "aws_instance" "Bastion_host" {
  depends_on = [
    aws_vpc.myvpc1,aws_security_group.Bastion_host_sg,
  ]
  ami = "ami-0e306788ff2473ccb"
  instance_type = "t2.micro"
  key_name = var.mykey
  associate_public_ip_address = true
  subnet_id = aws_subnet.public_subnet.id
  availability_zone = "ap-south-1a"
  vpc_security_group_ids = [ aws_security_group.Bastion_host_sg.id]
 
  tags = {
    Name = "bastion"
  }
}


resource "null_resource" "nullremote2"  {
  depends_on = [
    aws_instance.webpage,
  ]


provisioner "local-exec" {
	    command = "start chrome  ${aws_instance.webpage.public_ip}"
  	}
}
