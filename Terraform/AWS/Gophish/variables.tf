variable "region" {
  type    = string
  default = "us-west-2"
}

variable "vpc_name" {
  description = "Name of VPC"
  type        = string
  default     = "Gophish-vpc"
}

variable "vpc_cidr" {
  default = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  default = [
    "10.0.0.0/19",
    "10.0.32.0/19",
    "10.0.64.0/19"
  ]
}

variable "default_security_group_ingress" {
  description = "List of maps of ingress rules to set on the default Security Group"
  type        = list(map(string))
  default = [
    {
      cidr_blocks = "127.0.0.1/32" //Change CIDR to allow access
      description = "Allow HTTP from the internet."
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
    },
    {
      cidr_blocks = "127.0.0.1/32" //Change CIDR to allow access
      description = "Allow all HTTPS from the internet."
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
    },
    {
      cidr_blocks = "127.0.0.1/32" //Change CIDR to allow access
      description = "Allow HTTP 3333 from the internet."
      from_port   = 3333
      to_port     = 3333
      protocol    = "tcp"
    },
  ]
}

variable "default_security_group_egress" {
  description = "List of maps of egress rules to set on the default Security Group"
  type        = list(map(string))
  default = [
    {
      cidr_blocks = "0.0.0.0/0"
      description = "Allow all egress"
      from_port   = 0
      to_port     = 0
      protocol    = "all"
    }
  ]
}

variable "availability_zones" {
  description = "Available AZs"
  default = [
    "us-west-2a",
    "us-west-2b",
    "us-west-2c"
  ]
}


variable "instance_type" {
  description = "Default instance type"
  type        = string
  default     = "t3.micro"
}

variable "instance_name" {
  description = "Name of Gophish instance"
  type        = string
  default     = "Gophish-instance"
}

variable "user_data" {
  description = "User Data to install Gophish"
  type        = string
  /*base64 encoded version of:

  #!/bin/bash
  yum -y update
  yum -y install docker
  systemctl start docker
  systemctl enable docker
  usermod -a -G docker ec2-user
  docker run -d -p 80:80 -p 3333:3333 --name gophish gophish/gophish
  yum -y install https://s3.amazonaws.com/ec2-downloads-windows/SSMAgent/latest/linux_amd64/amazon-ssm-agent.rpm*/
  default = "IyEvYmluL2Jhc2gKeXVtIC15IHVwZGF0ZQp5dW0gLXkgaW5zdGFsbCBkb2NrZXIKc3lzdGVtY3RsIHN0YXJ0IGRvY2tlcgpzeXN0ZW1jdGwgZW5hYmxlIGRvY2tlcgp1c2VybW9kIC1hIC1HIGRvY2tlciBlYzItdXNlcgpkb2NrZXIgcnVuIC1kIC1wIDgwOjgwIC1wIDMzMzM6MzMzMyAtLW5hbWUgZ29waGlzaCBnb3BoaXNoL2dvcGhpc2gKeXVtIC15IGluc3RhbGwgaHR0cHM6Ly9zMy5hbWF6b25hd3MuY29tL2VjMi1kb3dubG9hZHMtd2luZG93cy9TU01BZ2VudC9sYXRlc3QvbGludXhfYW1kNjQvYW1hem9uLXNzbS1hZ2VudC5ycG0"
}

variable "asg_name" {
  description = "Name of Gophish ASG"
  type        = string
  default     = "Gophish-asg"
}
