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

// VPC and VSwitch
resource "alicloud_vpc" "rancher_k8s_vpc" {
  name = "rancher-k8s-vpc"
  cidr_block = "192.168.0.0/16"
}

data "alicloud_zones" "az" {
  network_type = "Vpc"
  available_disk_category = "cloud_ssd"
}
resource "alicloud_vswitch" "rancher_k8s_vswitch_zone_0" {
  name = "rancher-k8s-vswitch-zone-0"
  availability_zone = "${data.alicloud_zones.az.zones.0.id}"
  cidr_block = "192.168.0.0/24"
  vpc_id = "${alicloud_vpc.rancher_k8s_vpc.id}"
}
resource "alicloud_vswitch" "rancher_k8s_vswitch_zone_1" {
  name = "rancher-k8s-vswitch-zone-1"
  availability_zone = "${data.alicloud_zones.az.zones.1.id}"
  cidr_block = "192.168.0.1/24"
  vpc_id = "${alicloud_vpc.rancher_k8s_vpc.id}"
}

// Security group
resource "alicloud_security_group" "rancher_security_group" {
  name = "rancher-k8s-security-group"
  vpc_id = "${alicloud_vpc.rancher_k8s_vpc.id}"
}
resource "alicloud_security_group_rule" "accept_22_rule" {
  type = "ingress"
  ip_protocol = "tcp"
  nic_type = "intranet"
  policy = "accept"
  port_range = "22/22"
  priority = 1
  security_group_id = "${alicloud_security_group.rancher_security_group.id}"
  cidr_ip = "0.0.0.0/0"
}
resource "alicloud_security_group_rule" "accept_80_rule" {
  type = "ingress"
  ip_protocol = "tcp"
  nic_type = "intranet"
  policy = "accept"
  port_range = "80/80"
  priority = 1
  security_group_id = "${alicloud_security_group.rancher_security_group.id}"
  cidr_ip = "0.0.0.0/0"
}
resource "alicloud_security_group_rule" "accept_443_rule" {
  type = "ingress"
  ip_protocol = "tcp"
  nic_type = "intranet"
  policy = "accept"
  port_range = "443/443"
  priority = 1
  security_group_id = "${alicloud_security_group.rancher_security_group.id}"
  cidr_ip = "0.0.0.0/0"
}

// Kubernetes Cluster
data "alicloud_instance_types" "k8s_master_types_zone_0" {
  availability_zone = "${alicloud_vswitch.rancher_k8s_vswitch_zone_0.availability_zone}"
  cpu_core_count = "${var.master_instance_cpu_count}"
  memory_size = "${var.master_instance_ram_amount}"
}
data "alicloud_instance_types" "k8s_master_types_zone_1" {
  availability_zone = "${alicloud_vswitch.rancher_k8s_vswitch_zone_1.availability_zone}"
  cpu_core_count = "${var.master_instance_cpu_count}"
  memory_size = "${var.master_instance_ram_amount}"
}
data "alicloud_instance_types" "k8s_worker_types_zone_0" {
  availability_zone = "${alicloud_vswitch.rancher_k8s_vswitch_zone_0.availability_zone}"
  cpu_core_count = "${var.worker_instance_cpu_count}"
  memory_size = "${var.worker_instance_ram_amount}"
}
data "alicloud_instance_types" "k8s_worker_types_zone_1" {
  availability_zone = "${alicloud_vswitch.rancher_k8s_vswitch_zone_1.availability_zone}"
  cpu_core_count = "${var.worker_instance_cpu_count}"
  memory_size = "${var.worker_instance_ram_amount}"
}
resource "alicloud_cs_kubernetes" "rancher_k8s_cluster" {
  name_prefix = "rancher-k8s-cluster"
  vswitch_ids = [
    "${alicloud_vswitch.rancher_k8s_vswitch_zone_0.id}",
    "${alicloud_vswitch.rancher_k8s_vswitch_zone_1.id}",
    "${alicloud_vswitch.rancher_k8s_vswitch_zone_1.id}",
    // Note: the same VSwitch is used for 2 nodes, as several regions do not have 3 avalability zones
  ]

  master_instance_types = [
    "${data.alicloud_instance_types.k8s_master_types_zone_0.instance_types.0.id}",
    "${data.alicloud_instance_types.k8s_master_types_zone_1.instance_types.0.id}",
    "${data.alicloud_instance_types.k8s_master_types_zone_1.instance_types.0.id}",
  ]
  worker_instance_types = [
    "${data.alicloud_instance_types.k8s_worker_types_zone_0.instance_types.0.id}",
    "${data.alicloud_instance_types.k8s_worker_types_zone_1.instance_types.0.id}",
    "${data.alicloud_instance_types.k8s_worker_types_zone_1.instance_types.0.id}",
  ]
  master_disk_category = "cloud_ssd"
  worker_disk_category = "cloud_ssd"
  master_disk_size = "${var.master_instance_ram_amount}"
  worker_disk_size = "${var.worker_instance_ram_amount}"
  worker_numbers = [
    "${var.worker_instance_count}"
  ]
  password = "${var.ecs_root_password}"
  enable_ssh = true

  cluster_network_type = "flannel"
  pod_cidr = "172.20.0.0/16"
  service_cidr = "172.21.0.0/20"
}