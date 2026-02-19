data "aws_rds_cluster" "db" {
  cluster_identifier = var.db_cluster_id
}
