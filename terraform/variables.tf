# Variables Terraform - AFI
variable "location" {
  description = "Région Azure"
  type        = string
  default     = "francecentral"
}

variable "resource_group" {
  description = "Nom du groupe de ressources"
  type        = string
  default     = "rg-afi"
}

variable "node_count" {
  description = "Nombre de nœuds AKS"
  type        = number
  default     = 2
}

variable "vm_size" {
  description = "Taille des nœuds AKS"
  type        = string
  default     = "Standard_B2s"
}

variable "db_admin" {
  description = "Administrateur PostgreSQL"
  type        = string
  default     = "afi"
}

variable "db_password" {
  description = "Mot de passe PostgreSQL (à surcharger, jamais en dur)"
  type        = string
  sensitive   = true
}