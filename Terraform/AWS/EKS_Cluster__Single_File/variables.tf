variable "region" {
  description = "EKS cluster region"
  type        = string
  default     = "us-west-2"
}

variable "eks_cluster_name" {
  description = "Name of EKS cluster"
  type        = string
  default     = "my-eks-cluster"
}

variable "eks_cluster_version" {
  description = "EKS cluster version"
  type        = string
  default     = "1.28"
}

variable "eks_node_type" {
  description = "EKS Node type"
  type        = string
  default     = "t3.micro"
}
