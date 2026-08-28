# Cluster parameter group. Carried over from terraform-aws-postgres, plus
# rds.force_ssl.
#
# Hardcoded for the same reason as the opinions in main.tf: TLS enforcement and
# the logical replication posture are not things two clusters from this module
# should disagree about. A caller who genuinely needs different engine settings
# passes db_cluster_parameter_group_name, and the module creates no group at all.
#
# Created unless the caller supplies that name. name_prefix rather than name so
# create_before_destroy can swap the group under the cluster without a name
# collision.
resource "aws_rds_cluster_parameter_group" "this" {
  count       = var.enabled && var.db_cluster_parameter_group_name == null ? 1 : 0
  name_prefix = "${local.cluster_identifier_prefix}-"
  family      = local.cluster_parameter_group_family
  description = "Cluster parameter group for ${local.cluster_identifier_prefix}"
  tags        = merge(local.tags, var.tags)

  # NOT on by default for Aurora PostgreSQL, unlike RDS for PostgreSQL 15 and
  # later. Without it the engine accepts plaintext on 5432 no matter how private
  # the subnet is, which is the gap the security group cannot close.
  parameter {
    name         = "rds.force_ssl"
    value        = "1" # Enabled: reject non-TLS connections
    apply_method = "pending-reboot"
  }

  # The four logical replication values below are one decision, not four:
  # enhanced_logical_replication requires rds.logical_replication on and both
  # logical_replication_backup and logical_replication_globaldb off.
  parameter {
    name         = "rds.logical_replication"
    value        = "1" # Enabled
    apply_method = "pending-reboot"
  }

  parameter {
    name         = "aurora.enhanced_logical_replication"
    value        = "1" # Enabled
    apply_method = "pending-reboot"
  }

  parameter {
    name         = "aurora.logical_replication_backup"
    value        = "0" # Disabled
    apply_method = "pending-reboot"
  }

  parameter {
    name         = "aurora.logical_replication_globaldb"
    value        = "0" # Disabled
    apply_method = "pending-reboot"
  }

  lifecycle {
    create_before_destroy = true
  }
}
