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

// VSwitch in the first zone
data "alicloud_vswitches" "app_vswitches_zone_0" {
  name_regex = "sample-app-vswitch-zone-0-${var.env}"
}

// Ubuntu images
data "alicloud_images" "ubuntu_images" {
  owners = "system"
  name_regex = "ubuntu_18[a-zA-Z0-9_]+64"
  most_recent = true
}

// Instance type with 1 vCPU, 2 GB or RAM
data "alicloud_instance_types" "instance_types_zone_0" {
  cpu_core_count = 1
  memory_size = 2
  availability_zone = "${data.alicloud_vswitches.app_vswitches_zone_0.vswitches.0.zone_id}"
  network_type = "Vpc"
}
