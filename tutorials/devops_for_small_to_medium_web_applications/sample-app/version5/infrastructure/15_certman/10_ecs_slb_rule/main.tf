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

// Our custom certificate manager image
data "alicloud_images" "certman_images" {
  owners = "self"
  name_regex = "sample-app-certman-image-${var.env}"
  most_recent = true
}

// VSwitches in the first zone
data "alicloud_vswitches" "app_vswitches_zone_0" {
  name_regex = "sample-app-vswitch-zone-0-${var.env}"
}

// Security group
data "alicloud_security_groups" "app_security_groups" {
  name_regex = "sample-app-security-group-${var.env}"
}

// Load balancer
data "alicloud_slbs" "app_slbs" {
  name_regex = "sample-app-slb-${var.env}"
}

// Instance type with 1 vCPU, 0.5 GB or RAM
data "alicloud_instance_types" "instance_types_zone_0" {
  cpu_core_count = 1
  memory_size = 0.5
  availability_zone = "${data.alicloud_vswitches.app_vswitches_zone_0.vswitches.0.zone_id}"
  network_type = "Vpc"
}

// One ECS instance in the first availability zone
resource "alicloud_instance" "certman_ecs" {
  instance_name = "sample-app-certman-ecs-${var.env}"
  description = "Certificate manager (${var.env} environment)."

  host_name = "sample-app-certman-ecs-${var.env}"
  password = "${var.ecs_root_password}"

  image_id = "${data.alicloud_images.certman_images.images.0.id}"
  instance_type = "${data.alicloud_instance_types.instance_types_zone_0.instance_types.0.id}"

  internet_max_bandwidth_out = 1

  vswitch_id = "${data.alicloud_vswitches.app_vswitches_zone_0.vswitches.0.id}"
  security_groups = [
    "${data.alicloud_security_groups.app_security_groups.groups.0.id}"
  ]
}

// SLB VServer group
resource "alicloud_slb_server_group" "certman_server_group" {
  name = "sample-app-certman-slb-server-group-${var.env}"
  load_balancer_id = "${data.alicloud_slbs.app_slbs.slbs.0.id}"
  servers = [
    {
      server_ids = [
        "${alicloud_instance.certman_ecs.id}"
      ]
      port = 8080
      weight = 100
    }
  ]
}

// SLB forwarding rule
resource "alicloud_slb_rule" "rule" {
  name = "sample-app-certman-slb-rule-${var.env}"
  load_balancer_id = "${data.alicloud_slbs.app_slbs.slbs.0.id}"
  frontend_port = 80
  url = "/.well-known"
  server_group_id = "${alicloud_slb_server_group.certman_server_group.id}"
}
