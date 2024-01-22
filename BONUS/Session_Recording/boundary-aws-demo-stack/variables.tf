data "aws_caller_identity" "current" {}

resource "random_id" "foo_key" {
  prefix      = "foo"
  byte_length = 4
}

resource "random_id" "qux_key" {
  prefix      = "qux"
  byte_length = 4
}

resource "random_id" "bar_key" {
  prefix      = "bar"
  byte_length = 4
}

resource "random_id" "baz_key" {
  prefix      = "baz"
  byte_length = 4
}

variable "iam_user_count" {
  default = 2
}

locals {
  hashicorp_email = split(":", data.aws_caller_identity.current.user_id)[1]
  instance_tags = [
    {
      "${random_id.foo_key.dec}" = "test",
      "${random_id.qux_key.dec}" = "true",
    },
    {
      "${random_id.foo_key.dec}" = "prod",
      "${random_id.bar_key.dec}" = "true",
      "${random_id.qux_key.dec}" = "true",
    },
    {
      "${random_id.bar_key.dec}" = "true",
      "${random_id.qux_key.dec}" = "true",
    },
    {
      "${random_id.bar_key.dec}" = "true",
      "${random_id.baz_key.dec}" = "true",
      "${random_id.qux_key.dec}" = "true",
    },
    {
      "${random_id.baz_key.dec}" = "true",
      "${random_id.qux_key.dec}" = "true",
    },
  ]
}