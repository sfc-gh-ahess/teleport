// Region is AWS region, the region should support EFS
variable "region" {
  type = string
}

// Script creates a separate VPC with demo deployment
variable "vpc_cidr" {
  type    = string
  default = "172.31.0.0/16"
}

// Teleport cluster name to set up
variable "cluster_name" {
  type = string
}

// Teleport UID is a UID for teleport user provisioned on the hosts
variable "teleport_uid" {
  type    = string
  default = "1007"
}

// Instance types used for authentication servers auto scale groups
variable "auth_instance_type" {
  type    = string
  default = "m4.large"
}

// Instance types used for proxy auto scale groups
variable "proxy_instance_type" {
  type    = string
  default = "m4.large"
}

// Instance types used for teleport nodes auto scale groups
variable "node_instance_type" {
  type    = string
  default = "t2.medium"
}

// Instance types used for monitor auto scale groups
variable "monitor_instance_type" {
  type    = string
  default = "m4.large"
}

// SSH key name to provision instances withx
variable "key_name" {
  type = string
}

// DNS and letsencrypt integration variables
// Zone name to host DNS record, e.g. example.com
variable "route53_zone" {
  type = string
}

// Domain name to use for Teleport proxies,
// e.g. proxy.example.com
variable "route53_domain" {
  type = string
}

// Email for letsencrypt domain registration
variable "email" {
  type = string
}

// S3 Bucket to create for encrypted letsencrypt certificates
variable "s3_bucket_name" {
  type = string
}

// AWS KMS alias used for encryption/decryption
// default is alias used in SSM
variable "kms_alias_name" {
  default = "alias/aws/ssm"
}

// path to teleport enterprise/pro license file
variable "license_path" {
  type    = string
  default = ""
}

// AMI name to use
variable "ami_name" {
  type = string
}

// DynamoDB autoscale parameters
variable "autoscale_write_target" {
  type    = string
  default = 50
}

variable "autoscale_read_target" {
  type    = string
  default = 50
}

variable "autoscale_min_read_capacity" {
  type    = string
  default = 5
}

variable "autoscale_max_read_capacity" {
  type    = string
  default = 100
}

variable "autoscale_min_write_capacity" {
  type    = string
  default = 5
}

variable "autoscale_max_write_capacity" {
  type    = string
  default = 100
}

// InfluxDB and Telegraf versions
variable "influxdb_version" {
  type    = string
  default = "1.4.2"
}

variable "telegraf_version" {
  type    = string
  default = "1.5.1-1"
}

variable "grafana_version" {
  type    = string
  default = "4.6.3"
}

// Password for grafana admin user
variable "grafana_pass" {
  type = string
}

// Whether to use Amazon-issued certificates via ACM or not
// This must be set to true for any use of ACM whatsoever, regardless of whether Terraform generates/approves the cert
variable "use_acm" {
  type = string
  default = "false"
}

// Optional domain name to use for Teleport proxy NLB alias
// Only applied when using ACM, it will do nothing when ACM is disabled
// When using ACM we have one ALB (for port 443 with TLS termination) and one NLB
// (for all other traffic - 3023/3024/3026 etc)
// As this NLB is at a different address, we add an alias record in Route 53 so that
// it can be used by applications which connect to it directly (like kubectl) rather
// than discovering the NLB's address through the Teleport API (like tsh does)
variable "route53_domain_acm_nlb_alias" {
  type = string
  default = ""
}