# engine_version at create time. Its own file because run blocks share state
# within a file: once a cluster exists, ignore_changes correctly swallows a new
# engine_version, so create-time behaviour cannot be asserted after another run
# has already applied.
#
# This is also the file that pins the parameter group family to the engine's
# major version at create time, which is the pairing a mismatched family would
# break.

mock_provider "aws" {
  mock_data "aws_partition" {
    defaults = { partition = "aws" }
  }
  mock_data "aws_iam_policy_document" {
    defaults = { json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}" }
  }
}

mock_provider "random" {}

variables {
  vpc_id           = "vpc-0123456789abcdef0"
  intra_subnet_ids = ["subnet-0aaa", "subnet-0bbb"]
}

run "engine_version_applies_at_create_time" {
  command = apply

  variables {
    engine_version = "17.10.1"
  }

  assert {
    condition     = aws_rds_cluster.this[0].engine_version == "17.10.1"
    error_message = "engine_version must reach a cluster being created"
  }

  # The instances inherit from the cluster rather than reading the variable, so
  # there is one source of truth for the version.
  assert {
    condition     = aws_rds_cluster_instance.this[0].engine_version == aws_rds_cluster.this[0].engine_version
    error_message = "instances must inherit the cluster engine version"
  }

  assert {
    condition     = aws_rds_cluster_instance.this[0].engine == "aurora-postgresql"
    error_message = "instances must inherit the cluster engine"
  }

  # The family has to move with the engine, in the same apply.
  assert {
    condition     = aws_rds_cluster_parameter_group.this[0].family == "aurora-postgresql17"
    error_message = "the parameter group family must match the engine major version at create time"
  }
}
