variable "name" {
  type    = string
  default = "kuasar-prod"
}

variable "region" {
  type    = string
  default = "eu-central-1"
}

variable "vpc_cidr" {
  type    = string
  default = "10.20.0.0/16"
}

variable "kubernetes_version" {
  type    = string
  default = "1.31"
}

variable "node_instance_type" {
  type    = string
  default = "m6i.xlarge"
}

variable "min_nodes" {
  type    = number
  default = 3
}

variable "max_nodes" {
  type    = number
  default = 6
}

variable "database_instance_class" {
  type    = string
  default = "db.m6g.large"
}

variable "sandbox_instance_type" {
  type    = string
  default = "m6i.xlarge"
}

variable "key_pair_name" {
  description = "Existing EC2 key pair for SSH to the sandbox host."
  type        = string
}

variable "admin_cidrs" {
  type = list(string)
}
