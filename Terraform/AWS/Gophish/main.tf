#---------------------------------------------------------------
#
# Gophish installed on in a container on an EC2 instance in an
# ASG
#
#---------------------------------------------------------------


provider "aws" {
  region = var.region
}

module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name                           = var.vpc_name
  cidr                           = var.vpc_cidr
  azs                            = var.availability_zones
  public_subnets                 = var.public_subnet_cidrs
  default_security_group_ingress = var.default_security_group_ingress
  default_security_group_egress  = var.default_security_group_egress
  map_public_ip_on_launch        = true
  create_igw                     = true

  tags = {
    Terraform   = "true"
    Environment = "Gophish"
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

module "asg" {
  source = "terraform-aws-modules/autoscaling/aws"

  # Auto Scaling Group
  name = var.asg_name

  min_size                  = 0
  max_size                  = 1
  desired_capacity          = 1
  wait_for_capacity_timeout = 0
  health_check_type         = "EC2"
  vpc_zone_identifier       = module.vpc.public_subnets
  user_data                 = var.user_data

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

  # Launch Template
  launch_template_name        = "Gophish-ASG"
  launch_template_description = "Gophish Launch Template"
  update_default_version      = true

  image_id          = data.aws_ami.amazon-linux-2023.id
  instance_type     = var.instance_type
  ebs_optimized     = true
  enable_monitoring = true

  # IAM Role & Instance Profile
  create_iam_instance_profile = true
  iam_role_name               = "Gophish-ASG"
  iam_role_path               = "/ec2/"
  iam_role_description        = "Gophish ASG IAM Role"
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

  # This will ensure IMDSv2 is enabled, required, and a single hop which is an AWS security
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
      tags          = { Instance = "Gophish" }
    },
    {
      resource_type = "volume"
      tags          = { Volume = "Gophish Root Volume" }
    }
  ]

  tags = {
    Environment = "Gophish"
    Project     = "Gophish instance"
  }
}
