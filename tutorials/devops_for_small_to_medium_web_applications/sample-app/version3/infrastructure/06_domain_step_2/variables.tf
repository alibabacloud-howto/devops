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

variable "env" {
  description = "Environment (dev, pre-prod, prod)"
  default = "dev"
}

variable "domain_name" {
  description = "Domain name of the project."
  default = "my-sample-domain.xyz"
}

variable "sub_domain_name" {
  description = "Domain name corresponding to the environment (dev, pre-prod, www)."
  default = "dev"
}