# Fully mocked apply. No AWS credentials, no real resources, no cost.
# Run with: terraform test
#
# What this catches that `terraform plan` does not: every value that is
# "(known after apply)" during a plan becomes a concrete string here, so
# interpolations, merges, preconditions, and outputs are all evaluated for
# real. What it cannot catch is AWS API semantics -- an invalid engine
# version, a parameter name the engine family does not have, a KMS policy that
# denies the RDS service, a quota. Those still need the real apply of
# examples/complete.

mock_provider "aws" {
  # data.aws_partition drives the enhanced monitoring policy ARN, so give it
  # a real partition instead of a random mock string.
  mock_data "aws_partition" {
    defaults = {
      partition = "aws"
    }
  }

  # aws_iam_role validates that assume_role_policy is real JSON, so the mocked
  # policy document has to return real JSON rather than a random string.
  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
    }
  }
}

mock_provider "random" {}

variables {
  vpc_id           = "vpc-0123456789abcdef0"
  intra_subnet_ids = ["subnet-0aaa", "subnet-0bbb"]
}

run "hardcoded_posture" {
  command = apply

  assert {
    condition     = aws_rds_cluster.this[0].engine == "aurora-postgresql"
    error_message = "engine must be aurora-postgresql"
  }

  assert {
    condition     = aws_rds_cluster.this[0].engine_mode == "provisioned"
    error_message = "Serverless v2 requires engine_mode provisioned"
  }

  assert {
    condition     = aws_rds_cluster.this[0].port == 5432
    error_message = "port must be 5432"
  }

  assert {
    condition     = aws_rds_cluster.this[0].database_name == "this"
    error_message = "database_name must be hardcoded to this"
  }

  assert {
    condition     = aws_rds_cluster.this[0].master_username == "root"
    error_message = "master_username must be hardcoded to root"
  }

  assert {
    condition     = aws_rds_cluster.this[0].storage_encrypted == true
    error_message = "storage must be encrypted"
  }

  assert {
    condition     = aws_rds_cluster.this[0].iam_database_authentication_enabled == true
    error_message = "IAM database authentication must be enabled"
  }

  assert {
    condition     = aws_rds_cluster.this[0].enable_http_endpoint == false
    error_message = "the RDS Data API must stay off"
  }

  assert {
    condition     = aws_rds_cluster.this[0].backup_retention_period == 35
    error_message = "backup retention must be 35 days"
  }

  # Aurora PostgreSQL exports one log type, not the four aurora-mysql exports.
  assert {
    condition     = toset(aws_rds_cluster.this[0].enabled_cloudwatch_logs_exports) == toset(["postgresql"])
    error_message = "the postgresql log type must be exported, and it is the only one Aurora PostgreSQL has"
  }

  assert {
    condition     = aws_rds_cluster.this[0].skip_final_snapshot == false
    error_message = "destroy must leave a final snapshot"
  }

  assert {
    condition     = aws_rds_cluster.this[0].preferred_backup_window == "06:00-06:30"
    error_message = "backup window must be 06:00-06:30 UTC"
  }

  assert {
    condition     = aws_rds_cluster.this[0].allow_major_version_upgrade == false
    error_message = "major version upgrades must not happen unattended"
  }

  assert {
    condition     = aws_rds_cluster_instance.this[0].instance_class == "db.serverless"
    error_message = "instances must be db.serverless"
  }

  assert {
    condition     = aws_rds_cluster_instance.this[0].publicly_accessible == false
    error_message = "instances must not be publicly accessible"
  }

  assert {
    condition     = aws_rds_cluster_instance.this[0].performance_insights_enabled == true
    error_message = "Performance Insights must be on"
  }

  assert {
    condition     = aws_rds_cluster_instance.this[0].performance_insights_retention_period == 7
    error_message = "Performance Insights retention must be the 7 day free tier"
  }

  assert {
    condition     = aws_rds_cluster_instance.this[0].monitoring_interval == 60
    error_message = "enhanced monitoring must be on at 60s"
  }

  assert {
    condition     = aws_rds_cluster_instance.this[0].auto_minor_version_upgrade == true
    error_message = "minor version upgrades must be automatic"
  }

  # The Name tag is derived from cluster_identifier_prefix rather than taken
  # from a variable of its own.
  assert {
    condition     = aws_rds_cluster.this[0].tags["Name"] == "postgresdb-test"
    error_message = "the Name tag must be derived from cluster_identifier_prefix"
  }

  assert {
    condition     = aws_rds_cluster.this[0].tags["cost"] == "postgres"
    error_message = "the cost tag must be postgres"
  }

  # protect defaults to true, which must also pin apply_immediately off.
  assert {
    condition     = aws_rds_cluster.this[0].deletion_protection == true
    error_message = "deletion protection must default on"
  }

  assert {
    condition     = aws_rds_cluster.this[0].apply_immediately == false
    error_message = "apply_immediately must be the inverse of protect"
  }
}
