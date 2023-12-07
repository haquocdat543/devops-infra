variable "profile" {
  type = string
  default = "default"
}

variable "region" {
  type = string
  default = "ap-northeast-1"
}

variable "project" {
  description = "The project name to use for unique resource naming"
  type        = string
}

variable "principal_arns" {
  description = "A list of principal arns allowed to assume the IAM role"
  default     = null
  type        = list(string)
}
