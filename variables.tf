variable "region" {
  type        = string
  description = "default region"
  default     = "us-east-1"
}

variable "ami" {
  type        = string
  description = "default ami"
  defadefault = "ami-053b0d53c279acc90"
}

variable "instance_type" {
  type        = string
  description = "default instance type"
  ddefault    = "t2.micro"
}