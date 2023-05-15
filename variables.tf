variable "region" {
  default = "eu-west-2"
}

variable "vpc_cidr" {
  default = "10.0.0.0/16"
}

variable "azs" {
  default = ["eu-west-2a", "eu-west-2b", "eu-west-2c"]
}

variable "public_cidr_blocks" {
  default = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

variable "ami" {
  default = "ami-028a5cd4ffd2ee495"
}

variable "key_name" {
  default = "cba-web-KP"
}

variable "instance_type" {
  default = "t2.micro"
}

