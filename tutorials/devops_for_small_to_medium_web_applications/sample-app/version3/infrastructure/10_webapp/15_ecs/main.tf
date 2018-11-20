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

// Our custom application image
data "alicloud_images" "app_images" {
  owners = "self"
  name_regex = "sample-app-image-${var.env}"
  most_recent = true
}

// VSwitches in each zone
data "alicloud_vswitches" "app_vswitches_zone_0" {
  name_regex = "sample-app-vswitch-zone-0-${var.env}"
}
data "alicloud_vswitches" "app_vswitches_zone_1" {
  name_regex = "sample-app-vswitch-zone-1-${var.env}"
}

// Security group
data "alicloud_security_groups" "app_security_groups" {
  name_regex = "sample-app-security-group-${var.env}"
}

// Load balancer
data "alicloud_slbs" "app_slbs" {
  name_regex = "sample-app-slb-${var.env}"
}

// Instance type with 1 vCPU, 2 GB or RAM in each availability zone
data "alicloud_instance_types" "instance_types_zone_0" {
  cpu_core_count = 1
  memory_size = 2
  availability_zone = "${data.alicloud_vswitches.app_vswitches_zone_0.vswitches.0.zone_id}"
  network_type = "Vpc"
}
data "alicloud_instance_types" "instance_types_zone_1" {
  cpu_core_count = 1
  memory_size = 2
  availability_zone = "${data.alicloud_vswitches.app_vswitches_zone_1.vswitches.0.zone_id}"
  network_type = "Vpc"
}

// One ECS instance per availability zone
resource "alicloud_instance" "app_ecs_zone_0" {
  instance_name = "sample-app-ecs-zone-0-${var.env}"
  description = "Sample web application (${var.env} environment, first zone)."

  host_name = "sample-app-ecs-zone-0-${var.env}"
  password = "${var.ecs_root_password}"

  image_id = "${data.alicloud_images.app_images.images.0.id}"
  instance_type = "${data.alicloud_instance_types.instance_types_zone_0.instance_types.0.id}"

  vswitch_id = "${data.alicloud_vswitches.app_vswitches_zone_0.vswitches.0.id}"
  security_groups = [
    "${data.alicloud_security_groups.app_security_groups.groups.0.id}"
  ]
}
resource "alicloud_instance" "app_ecs_zone_1" {
  instance_name = "sample-app-ecs-zone-1-${var.env}"
  description = "Sample web application (${var.env} environment, second zone)."

  host_name = "sample-app-ecs-zone-1-${var.env}"
  password = "${var.ecs_root_password}"

  image_id = "${data.alicloud_images.app_images.images.0.id}"
  instance_type = "${data.alicloud_instance_types.instance_types_zone_1.instance_types.0.id}"

  vswitch_id = "${data.alicloud_vswitches.app_vswitches_zone_1.vswitches.0.id}"
  security_groups = [
    "${data.alicloud_security_groups.app_security_groups.groups.0.id}"
  ]
}

// SLB attachments
resource "alicloud_slb_attachment" "app_slb_attachment" {
  load_balancer_id = "${data.alicloud_slbs.app_slbs.slbs.0.id}"
  instance_ids = [
    "${alicloud_instance.app_ecs_zone_0.id}",
    "${alicloud_instance.app_ecs_zone_1.id}"
  ]
}