# Variables Terraform - AFI (AWS)
variable "region" {
  description = "Région AWS"
  type        = string
  default     = "eu-west-3"
}

variable "azs" {
  description = "Zones de disponibilité"
  type        = list(string)
  default     = ["eu-west-3a", "eu-west-3b"]
}

variable "account_id" {
  description = "ID du compte AWS (suffixe des buckets)"
  type        = string
}

variable "eks_version" {
  description = "Version Kubernetes"
  type        = string
  default     = "1.31"
}

variable "node_count" {
  description = "Nombre de nœuds EKS"
  type        = number
  default     = 2
}

variable "node_instance_type" {
  description = "Type d'instance des nœuds EKS"
  type        = string
  default     = "t3.medium"
}

variable "rds_instance_class" {
  description = "Classe d'instance RDS"
  type        = string
  default     = "db.t3.micro"
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

variable "ci_user" {
  description = "Utilisateur IAM utilisé par GitHub Actions pour déployer sur EKS"
  type        = string
  default     = "github-actions-afi"
}
