# The cluster parameter group: the one thing this module has that
# terraform-aws-aurora-v2 does not. Carried over from terraform-aws-postgres,
# plus rds.force_ssl.
#
# What these cannot check: whether AWS accepts the parameter names for the
# family. Mocks never call RDS, so a parameter that does not exist in
# aurora-postgresql18 passes here and fails on a real apply. That is what the
# manual examples/complete run in the module workflow is for.

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

run "force_ssl_is_on_by_default" {
  command = apply

  # The whole point of the group. Aurora PostgreSQL leaves rds.force_ssl off by
  # default, so a cluster on the AWS default parameter group accepts plaintext
  # on 5432 no matter how private the subnet is.
  assert {
    condition = anytrue([
      for p in aws_rds_cluster_parameter_group.this[0].parameter :
      p.name == "rds.force_ssl" && p.value == "1"
    ])
    error_message = "rds.force_ssl must be set to 1"
  }

  # A caller who passes nothing must land on the module's group, never on the
  # AWS default group.
  assert {
    condition     = length(aws_rds_cluster_parameter_group.this) == 1
    error_message = "the module must create a parameter group when the caller supplies no name"
  }

  assert {
    condition     = aws_rds_cluster.this[0].db_cluster_parameter_group_name == aws_rds_cluster_parameter_group.this[0].name
    error_message = "the cluster must be attached to the group the module created"
  }
}

run "logical_replication_posture" {
  command = apply

  # The four logical replication values carried over from
  # terraform-aws-postgres. enhanced_logical_replication needs
  # rds.logical_replication on and both of the others off, so these are one
  # decision rather than four.
  assert {
    condition = anytrue([
      for p in aws_rds_cluster_parameter_group.this[0].parameter :
      p.name == "rds.logical_replication" && p.value == "1"
    ])
    error_message = "rds.logical_replication must be 1"
  }

  assert {
    condition = anytrue([
      for p in aws_rds_cluster_parameter_group.this[0].parameter :
      p.name == "aurora.enhanced_logical_replication" && p.value == "1"
    ])
    error_message = "aurora.enhanced_logical_replication must be 1"
  }

  assert {
    condition = anytrue([
      for p in aws_rds_cluster_parameter_group.this[0].parameter :
      p.name == "aurora.logical_replication_backup" && p.value == "0"
    ])
    error_message = "aurora.logical_replication_backup must be 0"
  }

  assert {
    condition = anytrue([
      for p in aws_rds_cluster_parameter_group.this[0].parameter :
      p.name == "aurora.logical_replication_globaldb" && p.value == "0"
    ])
    error_message = "aurora.logical_replication_globaldb must be 0"
  }

  assert {
    condition     = length(aws_rds_cluster_parameter_group.this[0].parameter) == 5
    error_message = "the group must carry exactly the five parameters in main.tf"
  }

  # Every parameter in the group is static, so none of them can apply immediately.
  assert {
    condition = alltrue([
      for p in aws_rds_cluster_parameter_group.this[0].parameter :
      p.apply_method == "pending-reboot"
    ])
    error_message = "static parameters must be pending-reboot"
  }
}

# The family has to track the engine major version. Deriving it is the reason
# there is no separate family variable to disagree with engine_version.
run "family_follows_engine_version" {
  command = apply

  assert {
    condition     = aws_rds_cluster_parameter_group.this[0].family == "aurora-postgresql18"
    error_message = "the default engine version must produce the aurora-postgresql18 family"
  }
}

run "family_follows_a_pinned_major_version" {
  command = apply

  variables {
    engine_version = "17.10.1"
  }

  assert {
    condition     = aws_rds_cluster_parameter_group.this[0].family == "aurora-postgresql17"
    error_message = "pinning engine_version to 17.x must produce the aurora-postgresql17 family"
  }
}

# Supplying a name is the opt out: the module creates no group and attaches the
# caller's instead. Its own file because it changes what resources exist.
run "caller_supplied_group_replaces_the_module_group" {
  command = apply

  variables {
    db_cluster_parameter_group_name  = "my-own-group"
    db_instance_parameter_group_name = "my-own-instance-group"
  }

  assert {
    condition     = length(aws_rds_cluster_parameter_group.this) == 0
    error_message = "the module must create no group when the caller supplies a name"
  }

  assert {
    condition     = aws_rds_cluster.this[0].db_cluster_parameter_group_name == "my-own-group"
    error_message = "the caller's cluster parameter group must reach the cluster"
  }

  assert {
    condition     = aws_rds_cluster.this[0].db_instance_parameter_group_name == "my-own-instance-group"
    error_message = "the caller's instance parameter group must reach the cluster"
  }
}

run "disabled_creates_no_parameter_group" {
  command = apply

  variables {
    enabled = false
  }

  assert {
    condition     = length(aws_rds_cluster_parameter_group.this) == 0
    error_message = "enabled = false must create no parameter group"
  }

  assert {
    condition     = output.db_cluster_parameter_group_name == ""
    error_message = "the parameter group output must degrade to empty when disabled"
  }
}
