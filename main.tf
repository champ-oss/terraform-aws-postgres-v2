# -----------------------------------------------------------------------------
# Hardcoded module opinions.
#
# This module deliberately exposes very few variables. Everything in this block
# is a decision the module makes on the caller's behalf: Aurora PostgreSQL
# Serverless v2, private, encrypted, TLS only, fully logged and monitored.
# Change a value here and every consumer of the module moves together on the
# next apply, which is the point. Do not turn these back into variables without
# a concrete case where two clusters must legitimately differ.
# -----------------------------------------------------------------------------
locals {
  # engine
  engine      = "aurora-postgresql"
  engine_mode = "provisioned" # Serverless v2 is "provisioned" plus a scaling block

  # engine_version is deliberately NOT hardcoded. AWS applies minor version
  # upgrades in the maintenance window, so the real cluster drifts away from
  # whatever is written here. It stays a variable, and stays in ignore_changes.

  instance_class = "db.serverless"
  port           = 5432
  database_name  = "this"

  # credentials
  master_username = "root"
  password_length = 32

  # version upgrades
  allow_major_version_upgrade = false
  auto_minor_version_upgrade  = true

  # windows, UTC
  preferred_backup_window      = "06:00-06:30"
  preferred_maintenance_window = "sun:07:00-sun:07:30"

  # backups
  backup_retention_period = 35
  copy_tags_to_snapshot   = true

  # security posture
  enable_http_endpoint                = false # RDS Data API off, VPC only
  iam_database_authentication_enabled = true
  publicly_accessible                 = false
  storage_encrypted                   = true

  # observability. Aurora PostgreSQL exports one log type, not the four
  # aurora-mysql exports: there is no audit, general, or slowquery stream.
  # Statement logging is a parameter group setting, not a log type.
  enabled_cloudwatch_logs_exports       = ["postgresql"]
  monitoring_interval                   = 60
  performance_insights_enabled          = true
  performance_insights_retention_period = 7 # 7 days is the free tier

  # failover
  promotion_tier           = 2
  seconds_until_auto_pause = 300 # only applies when min_capacity is 0
}

# -----------------------------------------------------------------------------
# Derived values.
# -----------------------------------------------------------------------------
locals {
  # 60 character max length with 27 character random suffix
  cluster_identifier_prefix = trimsuffix(substr(var.cluster_identifier_prefix, 0, 33), "-")

  snapshot_timestamp = formatdate("'${local.cluster_identifier_prefix}-'YYYYMMDDHHmmss", timestamp())

  # The parameter group family has to track the engine's major version, so it
  # is derived from engine_version rather than passed in alongside it. Two
  # inputs for one idea is two chances for them to disagree, and a family that
  # disagrees with the engine is rejected at apply time.
  cluster_parameter_group_family = "aurora-postgresql${split(".", var.engine_version)[0]}"

  # name is derived rather than passed in. cluster_identifier_prefix is already
  # the caller's name for this cluster, so a separate variable was two inputs
  # for one idea and two chances to disagree with each other. This must stay
  # derived from var.cluster_identifier_prefix and not read
  # aws_rds_cluster.this[0].cluster_identifier: local.tags is applied to that
  # cluster, so reading it back would be a cycle.
  tags = {
    cost    = "postgres"
    creator = "terraform"
    Name    = local.cluster_identifier_prefix
  }
}
