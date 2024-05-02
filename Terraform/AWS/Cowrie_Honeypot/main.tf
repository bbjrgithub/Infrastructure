#---------------------------------------------------------------
#
# Cowrie honeypot installed on in a container on an EC2 instance
# in an ASG. A bastion host is used to access the Cowrie SSH
# session.
#
#---------------------------------------------------------------


provider "aws" {
  region = var.region
}

module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = var.vpc_name
  cidr = var.vpc_cidr

  azs                            = var.availability_zones
  public_subnets                 = var.public_subnet_cidrs
  private_subnets                = var.private_subnet_cidrs
  default_security_group_ingress = var.default_security_group_ingress
  default_security_group_egress  = var.default_security_group_egress

  //map_public_ip_on_launch = true

  enable_nat_gateway = true
  /*enable_vpn_gateway = true
  create_igw = true*/

  tags = {
    Terraform   = "true"
    Environment = "Cowrie"
  }
}

# Data for latest Amazon Linux 2023 Minimal AMI
data "aws_ami" "amazon-linux-2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "name"
    values = ["al2023-ami-minimal-2023.*-x86_64"]
  }
}

# ASG for Cowrie instance
module "Cowrie_asg" {
  source = "terraform-aws-modules/autoscaling/aws"

  # Autoscaling group
  name = var.cowrie_asg_name

  min_size                  = 0
  max_size                  = 1
  desired_capacity          = 1
  wait_for_capacity_timeout = 0
  health_check_type         = "EC2"
  vpc_zone_identifier       = module.vpc.private_subnets
  user_data                 = var.cowrie_user_data

  initial_lifecycle_hooks = [
    {
      name                  = "ExampleStartupLifeCycleHook"
      default_result        = "CONTINUE"
      heartbeat_timeout     = 60
      lifecycle_transition  = "autoscaling:EC2_INSTANCE_LAUNCHING"
      notification_metadata = jsonencode({ "hello" = "world" })
    },
    {
      name                  = "ExampleTerminationLifeCycleHook"
      default_result        = "CONTINUE"
      heartbeat_timeout     = 180
      lifecycle_transition  = "autoscaling:EC2_INSTANCE_TERMINATING"
      notification_metadata = jsonencode({ "goodbye" = "world" })
    }
  ]

  instance_refresh = {
    strategy = "Rolling"
    preferences = {
      checkpoint_delay       = 600
      checkpoint_percentages = [35, 70, 100]
      instance_warmup        = 300
      min_healthy_percentage = 50
      max_healthy_percentage = 100
    }
    triggers = ["tag"]
  }

  # Launch template
  launch_template_name        = "Cowrie-ASG"
  launch_template_description = "Cowrie Launch Template"
  update_default_version      = true

  image_id          = data.aws_ami.amazon-linux-2023.id
  instance_type     = var.instance_type
  ebs_optimized     = true
  enable_monitoring = true

  # IAM role & instance profile
  create_iam_instance_profile = true
  iam_role_name               = "Cowrie-ASG"
  iam_role_path               = "/ec2/"
  iam_role_description        = "Cowrie ASG IAM Role"
  iam_role_tags = {
    CustomIamRole = "Yes"
  }
  iam_role_policies = {
    AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  }

  block_device_mappings = [
    {
      # Root volume
      device_name = "/dev/xvda"
      no_device   = 0
      ebs = {
        delete_on_termination = true
        encrypted             = false
        volume_size           = 20
        volume_type           = "gp3"
      }
    }
  ]

  # This will ensure imdsv2 is enabled, required, and a single hop which is aws security
  # best practices
  # See https://docs.aws.amazon.com/securityhub/latest/userguide/autoscaling-controls.html#autoscaling-4
  metadata_options = {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  tag_specifications = [
    {
      resource_type = "instance"
      tags          = { Instance = "Cowrie" }
    },
    {
      resource_type = "volume"
      tags          = { Volume = "Cowrie Root Volume" }
    }
  ]

  tags = {
    Environment = "Cowrie"
    Project     = "Cowrie Instance"
  }
}

# ASG for bastion host to test Cowrie instance
module "bastion_asg" {
  source = "terraform-aws-modules/autoscaling/aws"

  # Autoscaling group
  name = var.bastion_asg_name

  min_size                  = 0
  max_size                  = 1
  desired_capacity          = 1
  wait_for_capacity_timeout = 0
  health_check_type         = "EC2"
  vpc_zone_identifier       = module.vpc.private_subnets
  user_data                 = var.bastion_user_data

  initial_lifecycle_hooks = [
    {
      name                  = "ExampleStartupLifeCycleHook"
      default_result        = "CONTINUE"
      heartbeat_timeout     = 60
      lifecycle_transition  = "autoscaling:EC2_INSTANCE_LAUNCHING"
      notification_metadata = jsonencode({ "hello" = "world" })
    },
    {
      name                  = "ExampleTerminationLifeCycleHook"
      default_result        = "CONTINUE"
      heartbeat_timeout     = 180
      lifecycle_transition  = "autoscaling:EC2_INSTANCE_TERMINATING"
      notification_metadata = jsonencode({ "goodbye" = "world" })
    }
  ]

  instance_refresh = {
    strategy = "Rolling"
    preferences = {
      checkpoint_delay       = 600
      checkpoint_percentages = [35, 70, 100]
      instance_warmup        = 300
      min_healthy_percentage = 50
      max_healthy_percentage = 100
    }
    triggers = ["tag"]
  }

  # Launch template
  launch_template_name        = "Bastion-ASG"
  launch_template_description = "Bastion Launch Template"
  update_default_version      = true

  image_id          = data.aws_ami.amazon-linux-2023.id
  instance_type     = var.instance_type
  ebs_optimized     = true
  enable_monitoring = true

  # IAM role & instance profile
  create_iam_instance_profile = true
  iam_role_name               = "Bastion-ASG"
  iam_role_path               = "/ec2/"
  iam_role_description        = "Bastion ASG IAM Role"
  iam_role_tags = {
    CustomIamRole = "Yes"
  }
  iam_role_policies = {
    AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  }

  block_device_mappings = [
    {
      # Root volume
      device_name = "/dev/xvda"
      no_device   = 0
      ebs = {
        delete_on_termination = true
        encrypted             = false
        volume_size           = 20
        volume_type           = "gp3"
      }
    }
  ]

  # This will ensure imdsv2 is enabled, required, and a single hop which is aws security
  # best practices
  # See https://docs.aws.amazon.com/securityhub/latest/userguide/autoscaling-controls.html#autoscaling-4
  metadata_options = {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  tag_specifications = [
    {
      resource_type = "instance"
      tags          = { Instance = "Bastion" }
    },
    {
      resource_type = "volume"
      tags          = { Volume = "Bastion Root Volume" }
    }
  ]

  tags = {
    Environment = "Bastion"
    Project     = "Bastion Host for Cowrie instance"
  }
}
