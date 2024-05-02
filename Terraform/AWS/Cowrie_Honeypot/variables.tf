variable "region" {
  type    = string
  default = "us-west-2"
}

variable "vpc_name" {
  description = "Name of VPC"
  type        = string
  default     = "Cowrie-vpc"
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

variable "private_subnet_cidrs" {
  default = [
    "10.0.96.0/19",
    "10.0.128.0/19",
    "10.0.160.0/19"
  ]
}

variable "default_security_group_ingress" {
  description = "List of maps of ingress rules to set on the default Security Group"
  type        = list(map(string))
  default = [
    {
      description = "Allow access to Cowrie port."
      self        = true
      from_port   = 2222
      to_port     = 2222
      protocol    = "tcp"
    }
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
  description = "Name of Cowrie instance"
  type        = string
  default     = "Cowrie-instance"
}

variable "cowrie_user_data" {
  description = "User Data to install Cowrie"
  type        = string
  /*base64 encoded version of:

  #!/bin/bash
  yum -y update
  yum -y install https://s3.amazonaws.com/ec2-downloads-windows/SSMAgent/latest/linux_amd64/amazon-ssm-agent.rpm
  yum -y install docker
  systemctl start docker
  systemctl enable docker
  usermod -a -G docker ssm-user
  docker run -d -p 2222:2222/tcp --name cowrie cowrie/cowrie*/
  default = "IyEvYmluL2Jhc2gKeXVtIC15IHVwZGF0ZQp5dW0gLXkgaW5zdGFsbCBodHRwczovL3MzLmFtYXpvbmF3cy5jb20vZWMyLWRvd25sb2Fkcy13aW5kb3dzL1NTTUFnZW50L2xhdGVzdC9saW51eF9hbWQ2NC9hbWF6b24tc3NtLWFnZW50LnJwbQp5dW0gLXkgaW5zdGFsbCBkb2NrZXIKc3lzdGVtY3RsIHN0YXJ0IGRvY2tlcgpzeXN0ZW1jdGwgZW5hYmxlIGRvY2tlcgp1c2VybW9kIC1hIC1HIGRvY2tlciBzc20tdXNlcgpkb2NrZXIgcnVuIC1kIC1wIDIyMjI6MjIyMi90Y3AgLS1uYW1lIGNvd3JpZSBjb3dyaWUvY293cmllCg=="
}

variable "cowrie_asg_name" {
  description = "Name of Cowrie ASG"
  type        = string
  default     = "Cowrie-asg"
}



variable "bastion_user_data" {
  description = "User Data to for Bastion gost"
  type        = string
  /*base64 encoded version of:

  #!/bin/bash
  yum -y update
  yum -y install https://s3.amazonaws.com/ec2-downloads-windows/SSMAgent/latest/linux_amd64/amazon-ssm-agent.rpm*/
  default = "IyEvYmluL2Jhc2gKeXVtIC15IHVwZGF0ZQp5dW0gLXkgaW5zdGFsbCBodHRwczovL3MzLmFtYXpvbmF3cy5jb20vZWMyLWRvd25sb2Fkcy13aW5kb3dzL1NTTUFnZW50L2xhdGVzdC9saW51eF9hbWQ2NC9hbWF6b24tc3NtLWFnZW50LnJwbQo="
}

variable "bastion_asg_name" {
  description = "Name of Bastion ASG"
  type        = string
  default     = "Bastion-asg"
}
