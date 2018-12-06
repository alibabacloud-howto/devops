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

variable "ecs_root_password" {
  description = "Root password for the ECS instances that forms the Kubernetes cluster."
  default = "YourRootPassword3000"
}

variable "master_instance_cpu_count" {
  description = "Number of vCPUs for one Kubernetes master node."
  default = 1
}

variable "master_instance_ram_amount" {
  description = "Amount of RAM in GB for one Kubernetes master node."
  default = 1
}

variable "master_instance_disk_size" {
  description = "Disk size in GB for one Kubernetes master node."
  default = 40
}

variable "worker_instance_count" {
  description = "Number of Kubernetes worker nodes."
  default = 1
}

variable "worker_instance_cpu_count" {
  description = "Number of vCPUs for one Kubernetes worker node."
  default = 1
}

variable "worker_instance_ram_amount" {
  description = "Amount of RAM in GB for one Kubernetes worker node."
  default = 1
}

variable "worker_instance_disk_size" {
  description = "Disk size in GB for one Kubernetes worker node."
  default = 40
}