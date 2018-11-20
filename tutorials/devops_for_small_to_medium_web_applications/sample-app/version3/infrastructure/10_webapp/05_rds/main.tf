/*
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

// Alibaba Cloud provider (source: https://github.com/terraform-providers/terraform-provider-alicloud)
provider "alicloud" {}

// Local backend (https://www.terraform.io/docs/backends/types/local.html)
terraform {
  backend "local" {}
}

// Multi-AZ RDS availability zone
data "alicloud_zones" "multi_az" {
  available_resource_creation = "Rds"
  multi = true
}

// VPC
data "alicloud_vpcs" "app_vpcs" {
  name_regex = "simple-app-vpc-${var.env}"
}

// VSwitch in the first zone
data "alicloud_vswitches" "app_vswitches_zone_0" {
  name_regex = "sample-app-vswitch-zone-0-${var.env}"
}

// MySQL RDS instance
resource "alicloud_db_instance" "app_rds" {
  instance_name = "sample-app-rds-${var.env}"

  // MySQL v5.7
  engine = "MySQL"
  engine_version = "5.7"

  // 5GB of storage
  instance_storage = 5

  // 1 core, 1GB of RAM
  instance_type = "rds.mysql.t1.small"

  // Make this RDS instance multi-AZ and link it to the VSwitch
  zone_id = "${data.alicloud_zones.multi_az.zones.0.id}"
  vswitch_id = "${data.alicloud_vswitches.app_vswitches_zone_0.vswitches.0.id}"

  // ECS instance IP addresses allowed to connect to this DB
  security_ips = [
    "${data.alicloud_vpcs.app_vpcs.vpcs.0.cidr_block}"
  ]
}

// MySQL database (~= schema)
resource "alicloud_db_database" "app_rds_db" {
  instance_id = "${alicloud_db_instance.app_rds.id}"
  name = "todolist"
  character_set = "utf8"
}

// MySQL user
resource "alicloud_db_account" "app_rds_db_account" {
  instance_id = "${alicloud_db_instance.app_rds.id}"
  name = "todolist"
  password = "${var.db_account_password}"
  type = "Normal"
}

// MySQL user privilege
resource "alicloud_db_account_privilege" "app_rds_db_account_privilege" {
  instance_id = "${alicloud_db_instance.app_rds.id}"
  account_name = "${alicloud_db_account.app_rds_db_account.name}"
  privilege = "ReadWrite"
  db_names = [
    "${alicloud_db_database.app_rds_db.name}"
  ]
}
