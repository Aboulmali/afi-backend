# Outputs Terraform - AFI (AWS)

output "eks_cluster_name" {
  value = aws_eks_cluster.afi.name
}

output "eks_cluster_endpoint" {
  value = aws_eks_cluster.afi.endpoint
}

output "rds_endpoint" {
  description = "Endpoint PostgreSQL (pour DATABASE_URL en prod)"
  value       = aws_db_instance.postgres.endpoint
}

output "rds_database" {
  value = aws_db_instance.postgres.db_name
}

output "uploads_bucket" {
  value = aws_s3_bucket.uploads.id
}

output "ecr_repository_url" {
  value = aws_ecr_repository.backend.repository_url
}
