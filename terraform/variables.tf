variable "region" {
  type    = string
  default = "eu-west-1"
}

variable "name" {
  type    = string
  default = "devops-platform-prod"
}

variable "vpc_cidr" {
  type    = string
  default = "10.20.0.0/16"
}

variable "kubernetes_version" {
  type    = string
  default = "1.31"
}

variable "node_instance_types" {
  type    = list(string)
  default = ["t3.large"]
}

variable "node_min" {
  type    = number
  default = 3
}

variable "node_max" {
  type    = number
  default = 6
}

variable "single_nat_gateway" {
  type        = bool
  default     = false
  description = "true saves cost in non-prod; false = one NAT gateway per AZ"
}

variable "api_allowed_cidrs" {
  type        = list(string)
  description = "CIDRs allowed to reach the public EKS API endpoint"
}
