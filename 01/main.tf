terraform {
    required_providers {
        aws = {
            source  = "hashicorp/aws"
            version = "~> 5.0"
        }
    }
}

provider "aws" {
    region = "ap-south-1"
}

resource "aws_instance" "FirstInstance" {
  ami           = "ami-0a17dd3aecf722a3c" # Ubuntu 20.04 LTS // ap-south-1
  instance_type = "t2.nano"
}