variable "aws_region" {
  description = "AWS Region"
  type        = string
  default     = "us-east-1"
}

variable "hf_token" {
  description = "Hugging Face Token for gated models (like Gemma)"
  type        = string
  sensitive   = true
  default     = ""
}

variable "model_id" {
  description = "Hugging Face Model ID to serve"
  type        = string
  default     = "google/gemma-4-E2B-it"
}

variable "enable_gpu" {
  description = "Set to true to deploy the optional GPU + vLLM LLM inference node instead of the default CPU + LightGBM node"
  type        = bool
  default     = false
}

variable "cpu_instance_type" {
  description = "Instance type for the default CPU (LightGBM) compute node"
  type        = string
  default     = "c7i-flex.large"
}

variable "gpu_instance_type" {
  description = "Instance type for the optional GPU (vLLM) compute node"
  type        = string
  default     = "g4dn.xlarge"
}

variable "allowed_ssh_cidr" {
  description = "Optional public IPv4 CIDR allowed to SSH to the bastion host (for example 203.0.113.10/32)"
  type        = string
  default     = null
  nullable    = true

  validation {
    condition     = var.allowed_ssh_cidr == null || (can(cidrhost(var.allowed_ssh_cidr, 0)) && can(regex("^(?:[0-9]{1,3}\\.){3}[0-9]{1,3}/32$", var.allowed_ssh_cidr)))
    error_message = "allowed_ssh_cidr must be a single IPv4 address in /32 CIDR form."
  }
}

variable "allowed_ssh_ipv6_cidr" {
  description = "Public IPv6 CIDR allowed to SSH to the bastion host (for example 2001:db8::1/128)"
  type        = string

  validation {
    condition     = can(cidrhost(var.allowed_ssh_ipv6_cidr, 0)) && strcontains(var.allowed_ssh_ipv6_cidr, ":") && endswith(var.allowed_ssh_ipv6_cidr, "/128")
    error_message = "allowed_ssh_ipv6_cidr must be a single IPv6 address in /128 CIDR form."
  }
}
