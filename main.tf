# Deploy a highly available web server on AWS using Terraform

# Declare AWS as the provider
provider "aws" {
  region = var.region
}

# Create a custom VPC
resource "aws_vpc" "web-vpc" {
  cidr_block = var.vpc_cidr
  tags = {
    Name = "web-vpc"
  }
}

# Create 3 public subnets in 3 AZs for HA
resource "aws_subnet" "web-public-subnet1" {
  vpc_id                  = aws_vpc.web-vpc.id
  cidr_block              = var.public_cidr_blocks[0]
  availability_zone       = var.azs[0]
  map_public_ip_on_launch = true

  tags = {
    Name = "web-public-subnet1"
  }

}

resource "aws_subnet" "web-public-subnet2" {
  vpc_id                  = aws_vpc.web-vpc.id
  cidr_block              = var.public_cidr_blocks[1]
  availability_zone       = var.azs[1]
  map_public_ip_on_launch = true

  tags = {
    Name = "web-public-subnet2"
  }

}

resource "aws_subnet" "web-public-subnet3" {
  vpc_id                  = aws_vpc.web-vpc.id
  cidr_block              = var.public_cidr_blocks[2]
  availability_zone       = var.azs[2]
  map_public_ip_on_launch = true

  tags = {
    Name = "web-public-subnet3"
  }

}

# Create an Internet Gateway
resource "aws_internet_gateway" "web-igw" {
  vpc_id = aws_vpc.web-vpc.id

  tags = {
    Name = "web-igw"
  }
}

# Create a Public Route Table
resource "aws_route_table" "web-public-rt" {
  vpc_id = aws_vpc.web-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.web-igw.id
  }

  tags = {
    Name = "web-public-rt"
  }
}

# Create route table associations for the 3 public subnets
resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.web-public-subnet1.id
  route_table_id = aws_route_table.web-public-rt.id
}

resource "aws_route_table_association" "b" {
  subnet_id      = aws_subnet.web-public-subnet2.id
  route_table_id = aws_route_table.web-public-rt.id
}

resource "aws_route_table_association" "c" {
  subnet_id      = aws_subnet.web-public-subnet3.id
  route_table_id = aws_route_table.web-public-rt.id
}

# Create Security Groups to open ports 80(HTTP) and 22(SSH)
resource "aws_security_group" "web-sg" {
  name        = "web-sg"
  description = "Allow inbound web traffic"
  vpc_id      = aws_vpc.web-vpc.id

  ingress {
    description = "Allow web traffic"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow SSH access"
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
    Name = "web-sg"
  }
}

# Create Application Load Balancer
resource "aws_lb" "web-alb" {
  name               = "web-alb"
  internal           = false
  load_balancer_type = "application"
  ip_address_type    = "ipv4"
  security_groups    = [aws_security_group.web-sg.id]
  subnets            = [aws_subnet.web-public-subnet1.id, aws_subnet.web-public-subnet2.id, aws_subnet.web-public-subnet3.id]

  tags = {
    Name = "web-alb"
  }
}

# Create a target group for the Application Load Balancer
resource "aws_lb_target_group" "web-alb-tg" {
  name        = "web-alb-tg"
  target_type = "instance"  
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.web-vpc.id
  health_check {
    protocol = "HTTP"
    path = "/index.html"
    port = 80
  }
  tags = {
    Name = "web-alb-tg"
  }
}

# Create ALB Listener to listen on port 80 and forward traffic to the instances in the target group
resource "aws_lb_listener" "web-alb-listener" {
  load_balancer_arn = aws_lb.web-alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web-alb-tg.arn
  }
}

# Create a Launch template for the Auto Scaling Group
resource "aws_launch_template" "web-lt" {
  name                 = "web-lt"
  image_id             = var.ami
  instance_type        = var.instance_type
  key_name             = var.key_name
  vpc_security_group_ids = [aws_security_group.web-sg.id]
  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "web-server"
    }
  }
  user_data = filebase64("script.sh")
  lifecycle {
    create_before_destroy = true
  }
}

# Create an Auto Scaling Group
resource "aws_autoscaling_group" "web-asg" {
  name              = "web-asg"
  desired_capacity  = 2
  max_size          = 2
  min_size          = 2  
  health_check_type = "ELB"  
  launch_template {
    id      = aws_launch_template.web-lt.id 
  }
  vpc_zone_identifier = [aws_subnet.web-public-subnet1.id, aws_subnet.web-public-subnet2.id, aws_subnet.web-public-subnet3.id]
  tag {
    key                 = "Name"
    value               = "web-asg"
    propagate_at_launch = true
  }
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_attachment" "asg_attachment_web" {
  autoscaling_group_name = aws_autoscaling_group.web-asg.id
  alb_target_group_arn    = aws_lb_target_group.web-alb-tg.arn
}