# AWS-EC2

This repository consists of Terraform templates to bring up a AWS EC2 instance with two NICs.

## Usage

- Clone this repo with: `git clone https://github.com/cklewar/aws-ec2`
- Enter repository directory with: `cd aws-ec2`
- Clone __modules__ repository with: `git clone https://github.com/cklewar/f5-xc-modules`
- Rename __modules__ repository directory name with: `mv f5-xc-modules modules`
- Export AWS `access_key` and `aws_secrect_key` environment variables
- Pick and choose from below examples and add mandatory input data and copy data into file `main.tf.example`
- Rename file __main.tf.example__ to __main.tf__ with: `rename main.tf.example main.tf`
- Apply with: `terraform apply -auto-approve` or destroy with: `terraform destroy -auto-approve`

### Example Output

```bash

```

## AWS EC2 example with Gitea

````hcl
vvariable "aws_region" {
  type    = string
  default = "us-west-1"
}

variable "aws_az" {
  type    = string
  default = "us-west-1a"
}

variable "aws_ec2_instance_userdata_dir_name" {
  type    = string
  default = "userdata"
}

variable "aws_ec2_instance_userdata_file_name" {
  type    = string
  default = "gitea.sh"
}

variable "aws_ec2_instance_userdata_template_name" {
  type    = string
  default = "gitea.tftpl"
}

output "template_file" {
  value = abspath("templates/${var.aws_ec2_instance_userdata_template_name}")
}

output "userdata_file" {
  value = abspath("_out/${var.aws_ec2_instance_userdata_file_name}")
}

module "aws_vpc" {
  source             = "./modules/aws/vpc"
  aws_region         = var.aws_region
  aws_az_name        = var.aws_az
  aws_vpc_cidr_block = "172.16.192.0/21"
  aws_vpc_name       = "ck-aws-ec2-test-vpc"
  custom_tags        = {
    Name  = "ck-aws-ec2-test-vpc"
    Owner = "c.klewar@f5.com"
  }
}

provider "aws" {
  region = var.aws_region
  alias  = "default"
}

module "aws_subnets" {
  source          = "./modules/aws/subnet"
  aws_vpc_id      = module.aws_vpc.aws_vpc_id
  aws_vpc_subnets = [
    {
      map_public_ip_on_launch = true
      cidr_block              = "172.16.192.0/24"
      availability_zone       = var.aws_az
      custom_tags             = {
        Name  = "ck-aws-ec2-test-public-subnet"
        Owner = "c.klewar@f5.com"
      }
    },
    {
      map_public_ip_on_launch = false
      cidr_block              = "172.16.193.0/24"
      availability_zone       = var.aws_az
      custom_tags             = {
        Name  = "ck-aws-ec2-test-private-subnet"
        Owner = "c.klewar@f5.com"
      }
    }
  ]

  custom_tags = {
    Owner = "c.klewar@f5.com"
  }

  providers = {
    aws = aws.default
  }
}

output "aws_subnet_ids" {
  value = [for s in module.aws_subnets.aws_subnet_id : s]
}

module "ec2" {
  source                    = "./modules/aws/ec2"
  aws_ec2_instance_name     = "ck-ec2-instance-01"
  aws_ec2_instance_type     = "t2.small"
  aws_ec2_public_ips        = ["172.16.192.10"]
  aws_ec2_private_ips       = ["172.16.193.10"]
  aws_ec2_instance_data_key = "ck-ec2-instance-01"
  aws_ec2_instance_data     = {
    inline = [
      format("chmod +x /tmp/%s", var.aws_ec2_instance_userdata_file_name),
      format("sudo /tmp/%s", var.aws_ec2_instance_userdata_file_name)
    ]
    userdata = {
      GITEA_VERSION = "1.16.9"
    }
  }
  aws_ec2_instance_userdata_file_name = var.aws_ec2_instance_userdata_file_name
  aws_ec2_instance_userdata_template  = abspath("templates/${var.aws_ec2_instance_userdata_template_name}")
  aws_ec2_instance_userdata_file      = abspath("_out/${var.aws_ec2_instance_userdata_file_name}")
  aws_ec2_instance_userdata_dir       = abspath(var.aws_ec2_instance_userdata_dir_name)
  aws_subnet_private_id               = element([for s in module.aws_subnets.aws_subnet_id : s], 1)
  aws_subnet_public_id                = element([for s in module.aws_subnets.aws_subnet_id : s], 0)
  aws_az_name                         = var.aws_az
  aws_region                          = var.aws_region
  ssh_private_key_file                = abspath("keys/key")
  ssh_public_key_file                 = abspath("keys/key.pub")
  aws_vpc_id                          = module.aws_vpc.aws_vpc_id
  custom_tags                         = {
    Name    = "ck-ec2-instance-01"
    Version = "1"
    Owner   = "c.klewar@f5.com"
  }
}

output "aws_ec2_instance_public_ip" {
  value = module.ec2.aws_ec2_instance_public_ip
}

output "aws_ec2_instance_public_dns" {
  value = module.ec2.aws_ec2_instance_public_dns
}
````

