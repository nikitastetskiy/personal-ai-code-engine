variable "source_url" {
  description = "Git repository URL used by Code Engine builds"
  type        = string
  default     = "https://github.com/nikitastetskiy/personal-ai-code-engine"
}

variable "ibmcloud_api_key" {
  description = "IBM Cloud API key used by the Terraform IBM provider."
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.ibmcloud_api_key) > 0
    error_message = "ibmcloud_api_key cannot be empty."
  }
}

variable "region" {
  description = "IBM Cloud region (example: us-south, eu-de, eu-gb). Used for Code Engine and Container Registry endpoint."
  type        = string
  default     = "eu-es"

  validation {
    condition     = can(regex("^[a-z]{2}-[a-z]+$", var.region))
    error_message = "region must look like 'us-south' or 'eu-de'."
  }
}

variable "icr_region" {
  description = "IBM Container Registry region prefix (example: us, de, es)."
  type        = string
  default     = "es"

  validation {
    condition     = can(regex("^[a-z]{2}$", var.icr_region))
    error_message = "icr_region must be a two-letter lowercase prefix such as us, de, or es."
  }
}

variable "prefix" {
  description = "Short lowercase prefix used in resource names."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,20}$", var.prefix))
    error_message = "prefix must match ^[a-z][a-z0-9-]{1,20}$ (lowercase, 2-21 chars, starts with a letter)."
  }
}

variable "resource_group" {
  description = "Base name for the resource group (suffix will be prefixed)."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,30}$", var.resource_group))
    error_message = "resource_group must match ^[a-z][a-z0-9-]{1,30}$ (lowercase, starts with a letter)."
  }
}

variable "cr_namespace" {
  description = "Container Registry namespace to store images."
  type        = string
  default     = "private-ai-ns"

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{1,28}[a-z0-9]$", var.cr_namespace))
    error_message = "cr_namespace must be 3-30 chars, lowercase letters/numbers/hyphens, and not start or end with a hyphen."
  }
}

variable "cos_bucket_name" {
  description = "Cloud Object Storage bucket name for Open WebUI persistence."
  type        = string
  default     = ""

  validation {
    condition     = var.cos_bucket_name == "" || can(regex("^[a-z0-9.-]{1,63}$", var.cos_bucket_name))
    error_message = "cos_bucket_name must be empty (auto) or a valid S3 bucket name style string (2-63 chars)."
  }
}

variable "ollama_image_tag" {
  description = "Tag for the Ollama image."
  type        = string
  default     = "latest"
}

variable "webui_image_tag" {
  description = "Tag for the Open WebUI image."
  type        = string
  default     = "latest"
}

# Separate the CR region from IBM Cloud region
variable "cr_region" {
  description = "Container Registry region prefix returned by `ibmcloud cr region` (example: us, eu, jp, global)."
  type        = string
  default     = "es"
}