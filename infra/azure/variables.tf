variable "subscription_id" {
  type = string
}

variable "name" {
  type    = string
  default = "kuasar-prod"
}

variable "location" {
  type    = string
  default = "germanywestcentral"
}

variable "vnet_cidr" {
  type    = string
  default = "10.40.0.0/16"
}

variable "kubernetes_version" {
  description = "Leave null for the default supported version."
  type        = string
  default     = null
}

variable "node_vm_size" {
  type    = string
  default = "Standard_D4s_v5"
}

variable "min_nodes" {
  type    = number
  default = 3
}

variable "max_nodes" {
  type    = number
  default = 6
}

variable "database_sku" {
  type    = string
  default = "GP_Standard_D2s_v3"
}

variable "sandbox_vm_size" {
  type    = string
  default = "Standard_D4s_v5"
}

variable "ssh_public_key" {
  type = string
}

variable "admin_cidrs" {
  type = list(string)
}
