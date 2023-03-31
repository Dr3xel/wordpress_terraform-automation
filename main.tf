# Specifie the configuration for Terraform, and declare the required AWS provider and version

terraform {
  required_providers {
    aws = {
    source  = "hashicorp/aws"
    version = "~> 3.27"
    }
  }

  required_version = ">= 0.14.9"
}

# Declare the provider for AWS and set the region

provider "aws" {
         region = "eu-central-1"
 }

# Declare a data source that retrieves the most recent Amazon Machine Image (AMI) 

 data "aws_ami" "ubuntu" {
   most_recent = true
 
   filter {
     name = "name"
     values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
   }
 
   filter {
     name = "virtualization-type"
     values = ["hvm"]
   }
 
   owners = ["099720109477"] # Canonical
 }

# Declare a security group resource for the VPC, allow incomming traffic on ports and outgoing traffic

 resource "aws_security_group" "security_terraform" {
   name = "security_terraform"
   vpc_id = "vpc-03d9774797f85663b"
   description = "security group for terraform"
 
   ingress {
     from_port = 80
     to_port = 80
     protocol = "tcp"
     cidr_blocks = ["0.0.0.0/0"]
   }
   
   ingress {
     from_port = 22
     to_port = 22
     protocol = "tcp"
     cidr_blocks = ["0.0.0.0/0"]
   }

   ingress {
    description = "MYSQL"
    from_port = 3306
    to_port = 3306
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
 
   egress {
     from_port = 0
     to_port = 65535
     protocol = "tcp"
     cidr_blocks = ["0.0.0.0/0"]
   }
 
   tags = {
     Name = "security_terraform"
   }
 }

# Creates an AWS security group called "RDS_allow_rules". It allows incoming traffic on port 3306 (MySQL) from the security group "security_terraform2". 

resource "aws_security_group" "security_rds" {
  name = "security_rds"
  vpc_id = "vpc-03d9774797f85663b"
  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = ["${aws_security_group.security_terraform.id}"]
  }
 
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  tags = {
    Name = "allow ec2"
  }
}

# Create an AWS launch configuration and set user data

 resource "aws_launch_configuration" "launch_conf" {
   image_id = data.aws_ami.ubuntu.id
   instance_type = "t2.micro"
   key_name = "wp_terraform"
   security_groups = ["security_terraform"]
   user_data = filebase64("script.sh")
 
   lifecycle {
       create_before_destroy = true
   }
 }

# Create an AWS auto scaling group and launch configuration

 resource "aws_autoscaling_group" "asg" {
   availability_zones = ["eu-central-1a", "eu-central-1b"]
   desired_capacity = 1
   max_size = 2
   min_size = 1
   load_balancers = [aws_elb.ELB.id]
   launch_configuration = aws_launch_configuration.launch_conf.id
 
   lifecycle {
       create_before_destroy = true
   }
 }

# Create AWS ELB resource

 resource "aws_elb" "ELB" {
   name = "ELB"
   availability_zones = ["eu-central-1a", "eu-central-1b"]
 
   listener {
     instance_port = 80
     instance_protocol = "http"
     lb_port = 80
     lb_protocol = "http"
   }
 
   health_check {
     healthy_threshold = 2
     unhealthy_threshold = 2
     timeout = 3
     target = "HTTP:80/"
     interval = 30
   }
   
   cross_zone_load_balancing = true
   idle_timeout = 400
   connection_draining = true
   connection_draining_timeout = 400
 
   tags = {
     Name = "ELB"
   }
 }

 output "elb_dns_name" {
 value = aws_elb.ELB.dns_name
 }

# Create an AWS RDS instance

resource "aws_db_instance" "db_RDS" {
allocated_storage = 10
identifier = "wordpressdb"
storage_type = "gp2"
engine = "mysql"
engine_version = "8.0"
instance_class = "db.t2.micro"
name = "wordpressdb"
username = "test_user"
password = "test_password"
publicly_accessible    = true
skip_final_snapshot    = true
vpc_security_group_ids = [aws_security_group.security_rds.id]

  tags = {
    Name = "ExampleRDSServerInstance"
  }
}
