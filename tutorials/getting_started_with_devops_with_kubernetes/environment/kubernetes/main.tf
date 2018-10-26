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

// Minimal environment for running a Kubernetes cluster in Alibaba Cloud.

provider "alicloud" {}

// Re-use the same VPC as the one used to host Gitlab and create another VSwitch (same availability zone)
data "alicloud_vswitches" "vswitches_ds" {
  name_regex = "cicdk8s-gitlab-vswitch"
}
resource "alicloud_vswitch" "vswitch" {
  name = "cicdk8s-k8s-vswitch"
  availability_zone = "${data.alicloud_vswitches.vswitches_ds.vswitches.0.zone_id}"
  cidr_block = "172.17.0.0/16"
  vpc_id = "${data.alicloud_vswitches.vswitches_ds.vswitches.0.vpc_id}"
}

// Kubernetes Cluster
data "alicloud_instance_types" "k8s_instance_types" {
  availability_zone = "${alicloud_vswitch.vswitch.availability_zone}"
  cpu_core_count = 2
  memory_size = 4
}
resource "alicloud_cs_kubernetes" "cluster" {
  name_prefix = "cicdk8s-cluster"
  vswitch_ids = [
    "${alicloud_vswitch.vswitch.id}"
  ]

  master_instance_types = [
    "${data.alicloud_instance_types.k8s_instance_types.instance_types.0.id}"
  ]
  worker_instance_types = [
    "${data.alicloud_instance_types.k8s_instance_types.instance_types.0.id}"
  ]
  master_disk_category = "cloud_ssd"
  worker_disk_category = "cloud_ssd"
  master_disk_size = 40
  worker_disk_size = 40
  worker_numbers = [
    3
  ]
  password = "${var.k8s_password}"
  enable_ssh = true

  cluster_network_type = "flannel"
  pod_cidr = "10.0.0.0/16"
  service_cidr = "10.1.0.0/16"
}