# Configure the AWS Provider
provider "aws" {
  region = "us-east-1"
  //authentication 
  access_key = "ASIAQ6GTPRZNVHNXI24Q"
  secret_key = "xMq/aOl5zr0HbxC6oMYyBX9ILOlTyrShg6y8RaUL"
}
# Create a VPC
resource "aws_vpc" "main_vpc" {
  cidr_block = "10.0.0.0/16"
  tag = {
    Name = "main"
  }
}
# internet gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main_vpc.id
}

# Create a Public Subnet
resource "aws_subnet" "public_sub" {
  vpc_id            = aws_vpc.main_vpc.id
  cidr_block        = "10.0.0.0/24"
  availability_zone = "us-east-1a"
}
#create EC2 instance 1
resource "aws_instance" "my_first_instance" {
  ami           = "ami-05fa00d4c63e32376"
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.public_sub.id

}

# nat gateway
resource "aws_nat_gateway" "natgw" {
  allocation_id = aws_eip.elasticip.id
  subnet_id     = aws_subnet.public_sub.id

  tags = {
    Name = "NAT gw"
  }

  # To ensure proper ordering, it is recommended to add an explicit dependency
  # on the Internet Gateway for the VPC.
  depends_on = [aws_internet_gateway.natgw]
}

# Create Public route table 
resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.main_vpc.id

  route {
    cidr_block = "10.0.0.0/24"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = {
    Name = "main"
  }
}
# assign the public subnet to the route table
resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.public_sub.id
  route_table_id = aws_route_table.public_route_table.id
}

#Create a private subnet
resource "aws_subnet" "private_sub" {
  vpc_id            = aws_vpc.main_vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-1a"
}
#create EC2 instance 2
resource "aws_instance" "my_second_instance" {
  ami             = data.aws_ami.ubuntu.id
  instance_type   = "t3.micro"
  subnet_id       = aws_instance.my_second_instance.id
  security_groups = ["allow_web"]
}
# Create Private route table for private subnet and the workload subnet
resource "aws_route_table" "private_route_table" {
  vpc_id = aws_vpc.main_vpc.id

  route {
    cidr_block     = "10.0.1.0/24"
    nat_gateway_id = aws_nat_gateway.natgw.id
  }
  tags = {
    Name = "main"
  }
}
# assign the private subnet to a route table
resource "aws_route_table_association" "b" {
  subnet_id      = aws_subnet.private_sub.id
  route_table_id = aws_route_table.private_route_table.id

}

#Create a subnet for the workload
resource "aws_subnet" "workload_sub" {
  vpc_id            = aws_vpc.main_vpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "us-east-1a"
  tag {
    Name = "workload subnet"
  }
}

#create EC2 instance 3 in the workload subnet
resource "aws_instance" "my_third_instance" {
  ami             = data.aws_ami.ubuntu.id
  instance_type   = "t3.micro"
  subnet_id       = aws_instance.my_third_instance.id
  security_groups = ["allow_traffic", "allow_web"]
}
# elastic ip for the workload instance
resource "aws_eip" "elasticip" {
  instance = aws_instance.my_third_instance.id
  vpc      = true
}

# Create Workload route table 
resource "aws_route_table" "workload_route_table" {
  vpc_id = aws_vpc.main_vpc.id

  route {
    cidr_block     = "10.0.2.0/24"
    nat_gateway_id = aws_nat_gateway.natgw.id
  }
  tags = {
    Name = "main"
  }
}

# assign the workload subnet to a route table
resource "aws_route_table_association" "c" {
  subnet_id      = aws_subnet.workload_sub.id
  route_table_id = aws_route_table.workload_route_table.id
}

# create a security group for the private instances to access internet
resource "aws_security_group" "allow_web" {
  name        = "allow_web_traffic"
  description = "Allow web inbound traffic"
  vpc_id      = aws_vpc.main_vpc.id

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.main.cidr_block]
  }
  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.main.cidr_block]
  }
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.main.cidr_block]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow_web"
  }
}


# create a security group for the instance of the workload subnet
resource "aws_security_group" "allow_traffic" {
  name        = "allow_traffic"
  description = "Allow inbound traffic"
  vpc_id      = aws_vpc.main_vpc.id

  egress {
    from_port   = 22
    to_port     = 22
    protocol    = "ssh"
    cidr_blocks = ["10.0.2.0/24"]
  }

  tags = {
    Name = "allow_web"
  }
}

#network access list for the private subnet
resource "aws_network_acl" "private_sub" {
  vpc_id = aws_vpc.main_vpc.id

  egress {
    protocol   = "-1"
    rule_no    = 200
    action     = "allow"
    cidr_block = "10.0.2.0/24"

  }

  ingress {
    protocol   = "-1"
    rule_no    = 100
    action     = "allow"
    cidr_block = "10.0.2.0/24"

  }
}

#network access list for the public subnet
resource "aws_network_acl" "public_sub" {
  vpc_id = aws_vpc.main_vpc.id

  egress {
    protocol   = "-1"
    rule_no    = 200
    action     = "allow"
    cidr_block = "10.0.2.0/24"

  }

  ingress {
    protocol   = "-1"
    rule_no    = 100
    action     = "allow"
    cidr_block = "10.0.2.0/24"

  }
}

#network access list for the workload subnet
resource "aws_network_acl" "private_sub" {
  vpc_id = aws_vpc.main_vpc.id

  egress {
    protocol   = "-1"
    rule_no    = 200
    action     = "allow"
    cidr_block = ["10.0.0.0/24", "10.0.1.0/24"]

  }

  ingress {
    protocol   = "-1"
    rule_no    = 100
    action     = "allow"
    cidr_block = ["10.0.0.0/24", "10.0.1.0/24"]

  }
}
