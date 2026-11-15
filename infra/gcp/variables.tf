variable "project_id" {
  type = string
}

variable "name" {
  type    = string
  default = "kuasar-prod"
}

variable "region" {
  type    = string
  default = "europe-west3"
}

variable "zone" {
  description = "Zone of the sandbox host."
  type        = string
  default     = "europe-west3-a"
}

variable "subnet_cidr" {
  type    = string
  default = "10.30.0.0/20"
}

variable "pods_cidr" {
  type    = string
  default = "10.31.0.0/16"
}

variable "services_cidr" {
  type    = string
  default = "10.32.0.0/20"
}

variable "node_machine_type" {
  type    = string
  default = "e2-standard-4"
}

variable "min_nodes_per_zone" {
  type    = number
  default = 1
}

variable "max_nodes_per_zone" {
  type    = number
  default = 2
}

variable "database_tier" {
  type    = string
  default = "db-custom-2-7680"
}

variable "sandbox_machine_type" {
  type    = string
  default = "e2-standard-4"
}

variable "admin_cidrs" {
  type = list(string)
}
