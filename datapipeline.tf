# This is a Terraform file to create the DataPipeline job for synching two S3
# buckets, that can be on two different accounts.
#
# For more information, see the README.md file

# Mandatory Parameters
variable "source_bucket_name"     { }
variable "target_bucket_name"     { }

# Optional Parameters
variable "cf_stack_prefix"        { default = "S3Copy" }
variable "iam_config"             { default = "iam_source" }
variable "instance_type"          { default = "i3.large" }
variable "disk_size_gb"           { default = "1000" }
variable "source_bucket_path"     { default = "" }
variable "target_bucket_path"     { default = "" }

resource "aws_cloudformation_stack" "datapipeline" {
  name            = "${var.cf_stack_prefix}_${var.source_bucket_name}_to_${var.target_bucket_name}"
  on_failure      = "DELETE"

  template_body   = "${file("${module.path}/datapipeline.yml")}"

  parameters      = {
    SubnetId        = "${var.iam_config}"
    Timeout         = "${var.source_bucket_name}"
    CreateLogBucket = "${var.target_bucket_name}"
    LogBucketName   = "${var.instance_type}"
    InstanceType    = "${var.disk_size_gb}"
  }
}
