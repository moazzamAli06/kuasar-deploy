variable "name" {
  description = "Prefix for every resource."
  type        = string
  default     = "kuasar-prod"
}

variable "region" {
  type    = string
  default = "fra1"
}

variable "vpc_cidr" {
  type    = string
  default = "10.116.0.0/20"
}

variable "node_size" {
  type    = string
  default = "s-4vcpu-8gb"
}

variable "min_nodes" {
  type    = number
  default = 3
}

variable "max_nodes" {
  type    = number
  default = 6
}

variable "database_size" {
  type    = string
  default = "db-s-2vcpu-4gb"
}

variable "sandbox_size" {
  type    = string
  default = "s-4vcpu-8gb"
}

variable "ssh_key_fingerprints" {
  description = "Fingerprints of the SSH keys that may log in to the sandbox host."
  type        = list(string)
}

variable "admin_cidrs" {
  description = "Source ranges allowed to SSH to the sandbox host."
  type        = list(string)
}
