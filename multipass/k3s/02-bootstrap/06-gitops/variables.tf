variable "git_revision" {
  description = "Git branch Argo CD uses for application definitions and manifests."
  type        = string
  default     = "main"

  validation {
    condition     = length(trimspace(var.git_revision)) > 0
    error_message = "git_revision must not be empty."
  }
}

variable "git_repo_url" {
  description = "Git repository URL Argo CD uses for application definitions and manifests."
  type        = string
  default     = "https://github.com/emter80/kubernetes-mate-lab.git"

  validation {
    condition     = can(regex("^https?://|^ssh://|^git@", var.git_repo_url))
    error_message = "git_repo_url must be an HTTPS or SSH Git URL."
  }
}