# AWS-EC2

This repository consists of Terraform templates to bring up a AWS EC2 instance with two NICs.

## Usage

- Clone this repo with: `git clone --recurse-submodules https://github.com/cklewar/aws-ec2`
- Enter repository directory with: `cd aws-ec2`
- Export AWS `access_key` and `aws_secrect_key` environment variables
- Pick and choose from below examples and add mandatory input data and copy data into file `main.tf.example`
- Rename file __main.tf.example__ to __main.tf__ with: `rename main.tf.example main.tf`
- Initialize with: `terraform init`
- Apply with: `terraform apply -auto-approve` or destroy with: `terraform destroy -auto-approve`

## AWS EC2 module common variables example
````hcl
variable "project_prefix" {
  type        = string
  description = "prefix string put in front of string"
  default     = "f5xc"
}

variable "project_suffix" {
  type        = string
  description = "prefix string put at the end of string"
  default     = "01"
}

variable "aws_region" {
  type    = string
  default = "us-west-1"
}

variable "aws_az" {
  type    = string
  default = "us-west-1a"
}

variable "aws_ec2_instance_script_file_name" {
  type    = string
  default = "gitea.sh"
}

variable "aws_ec2_instance_script_template_file_name" {
  type    = string
  default = "gitea.tftpl"
}

variable "gitea_version" {
  type    = string
}

variable "gitea_password" {
  type    = string
}

variable "rendered_template_output_path" {
  type    = string
  default = "_out/"
}

variable "custom_data_dir" {
  type    = string
  default = "custom_data"
}

variable "aws_ec2_instance_name" {
  type    = string
  default = "ec2-instance-01"
}

variable "aws_ec2_02_instance_name" {
  type    = string
  default = "ec2-instance-02"
}

variable "ssh_private_key_file" {
  type    = string
}

variable "ssh_public_key_file" {
  type    = string
}

variable "f5xc_aws_tgw_workload_subnet" {
  type    = string
  default = "192.168.168.0/26"
}

provider "aws" {
  region = var.aws_region
  alias  = "default"
}

locals {
  template_output_dir_path = abspath("_out/")
  template_input_dir_path  = abspath("templates/")
  custom_tags              = {
    f5xc-feature = "aws-ec2"
    f5xc-tenant  = "playground"
  }
}

module "aws_vpc" {
  source             = "./modules/aws/vpc"
  aws_region         = var.aws_region
  aws_az_name        = var.aws_az
  aws_vpc_cidr_block = "172.16.192.0/21"
  aws_vpc_name       = format("%s-aws-ec2-test-vpc-%s", var.project_prefix, var.project_suffix)
  aws_owner          = var.owner
  custom_tags        = local.custom_tags
  providers          = {
    aws = aws.default
  }
}

module "aws_subnet" {
  source          = "./modules/aws/subnet"
  aws_vpc_id      = module.aws_vpc.aws_vpc["id"]
  aws_vpc_subnets = [
    {
      name                    = format("%s-aws-ec2-test-public-subnet-%s", var.project_prefix, var.project_suffix)
      owner                   = var.owner
      map_public_ip_on_launch = true
      cidr_block              = "172.16.192.0/24"
      availability_zone       = var.aws_az
      custom_tags             = local.custom_tags
    },
    {
      name                    = format("%s-aws-ec2-test-private-subnet-%s", var.project_prefix, var.project_suffix)
      owner                   = var.owner
      map_public_ip_on_launch = false
      cidr_block              = "172.16.193.0/24"
      availability_zone       = var.aws_az
      custom_tags             = local.custom_tags
    }
  ]
  providers = {
    aws = aws.default
  }
}

resource "aws_internet_gateway" "igw" {
  provider = aws.default
  vpc_id   = module.aws_vpc.aws_vpc["id"]
  tags     = merge({ "Owner" : var.owner }, local.custom_tags)
}

resource "aws_route_table" "rt" {
  provider = aws.default
  vpc_id   = module.aws_vpc.aws_vpc["id"]
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = merge({ "Owner" : var.owner }, local.custom_tags)
}

resource "aws_route_table_association" "subnet" {
  provider       = aws.default
  for_each       = module.aws_subnet.aws_subnets
  subnet_id      = each.value.id
  route_table_id = aws_route_table.rt.id
}

module "aws_security_group_private" {
  source                     = "./modules/aws/security_group"
  aws_security_group_name    = format("%s-%s-%s-private-sg", var.project_prefix, var.aws_ec2_01_instance_name, var.project_suffix)
  aws_vpc_id                 = module.aws_vpc.aws_vpc["id"]
  security_group_rule_egress = [
    {
      from_port   = 0
      to_port     = 0
      protocol    = -1
      cidr_blocks = ["0.0.0.0/0"]
    }
  ]
  security_group_rule_ingress = [
    {
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = ["10.0.0.0/8"]
    },
    {
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = ["172.16.0.0/16"]
    },
    {
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = ["192.168.0.0/16"]
    }
  ]
  providers = {
    aws = aws.default
  }
}

module "aws_security_group_public" {
  source                     = "./modules/aws/security_group"
  aws_security_group_name    = format("%s-%s-%s-public-sg", var.project_prefix, var.aws_ec2_01_instance_name, var.project_suffix)
  aws_vpc_id                 = module.aws_vpc.aws_vpc["id"]
  security_group_rule_egress = [
    {
      from_port   = 0
      to_port     = 0
      protocol    = -1
      cidr_blocks = ["0.0.0.0/0"]
    }
  ]
  security_group_rule_ingress = [
    {
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  ]
  providers = {
    aws = aws.default
  }
}
````

## AWS EC2 example with Gitea and referenced interfaces

````hcl
module "aws_network_interface_public" {
  source                        = "./modules/aws/network_interface"
  aws_interface_create_eip      = true
  aws_interface_private_ips     = ["172.16.192.10"]
  aws_interface_security_groups = [module.aws_security_group_public.aws_security_group["id"]]
  aws_interface_subnet_id       = module.aws_subnet.aws_subnets[format("%s-aws-ec2-test-public-subnet-%s", var.project_prefix, var.project_suffix)]["id"]
  custom_tags     = {
        "tagA" = "ValueA"
      }
  providers                     = {
    aws = aws.default
  }
}

module "aws_network_interface_private" {
  source                        = "./modules/aws/network_interface"
  aws_interface_create_eip      = false
  aws_interface_private_ips     = ["172.16.193.10"]
  aws_interface_security_groups = [module.aws_security_group_private.aws_security_group["id"]]
  aws_interface_subnet_id       = module.aws_subnet.aws_subnets[format("%s-aws-ec2-test-private-subnet-%s", var.project_prefix, var.project_suffix)]["id"]
  providers                     = {
    aws = aws.default
  }
}

module "ec2_01_interface_ref" {
  source                  = "./modules/aws/ec2"
  owner                   = var.owner
  aws_ec2_instance_name   = format("%s-%s-%s", var.project_prefix, var.aws_ec2_01_instance_name, var.project_suffix)
  aws_ec2_instance_type   = "t2.small"
  aws_ec2_instance_script = {
    actions = [
      format("chmod +x /tmp/%s", var.aws_ec2_instance_script_file_name),
      format("sudo /tmp/%s", var.aws_ec2_instance_script_file_name)
    ]
    template_data = {
      CUSTOM_DATA_DIR = format("%s/vcs", var.custom_data_dir)
      PREFIX          = var.f5xc_aws_tgw_workload_subnet
      GATEWAY         = cidrhost(module.aws_subnet.aws_subnets[format("%s-aws-ec2-test-private-subnet-%s", var.project_prefix, var.project_suffix)]["cidr_block"], 1)
      GITEA_VERSION   = var.gitea_version
      GITEA_PASSWORD  = var.gitea_password
    }
  }
  aws_ec2_instance_script_template = var.aws_ec2_instance_script_template_file_name
  aws_ec2_instance_script_file     = var.aws_ec2_instance_script_file_name
  aws_az_name                      = var.aws_az
  aws_region                       = var.aws_region
  ssh_private_key                  = file(var.ssh_private_key_file)
  ssh_public_key                   = file(var.ssh_public_key_file)
  template_output_dir_path         = local.template_output_dir_path
  template_input_dir_path          = local.template_input_dir_path
  aws_ec2_network_interfaces_ref   = [
    {
      device_index         = 0
      network_interface_id = module.aws_network_interface_public.aws_network_interface["id"]
    },
    {
      device_index         = 1
      network_interface_id = module.aws_network_interface_private.aws_network_interface["id"]
    }
  ]
  aws_ec2_instance_custom_data_dirs = [
    {
      name        = "instance_script"
      source      = "${local.template_output_dir_path}/${var.aws_ec2_instance_script_file_name}"
      destination = format("/tmp/%s", var.aws_ec2_instance_script_file_name)
    },
    {
      name        = "additional_custom_data"
      source      = abspath(var.custom_data_dir)
      destination = "/tmp"
    }
  ]
  custom_tags = local.custom_tags
  providers   = {
    aws = aws.default
  }
}

output "ec2_01" {
  value = module.ec2_01_interface_ref.aws_ec2_instance
}

output "script_template_file" {
  value = abspath("templates/${var.aws_ec2_instance_script_template_file_name}")
}

output "rendered_script_file" {
  value = "${local.template_output_dir_path}/${var.aws_ec2_instance_script_file_name}"
}

output "aws_subnet_ids" {
  value = module.aws_subnet.aws_subnets
}
````

## AWS EC2 example with Gitea and inline interfaces

````hcl
module "ec2_02_interface_inline" {
  source                  = "./modules/aws/ec2"
  owner                   = var.owner
  aws_ec2_instance_name   = format("%s-%s-%s", var.project_prefix, var.aws_ec2_02_instance_name, var.project_suffix)
  aws_ec2_instance_type   = "t2.small"
  aws_ec2_instance_script = {
    actions = [
      format("chmod +x /tmp/%s", var.aws_ec2_instance_script_file_name),
      format("sudo /tmp/%s", var.aws_ec2_instance_script_file_name)
    ]
    template_data = {
      CUSTOM_DATA_DIR = format("%s/vcs", var.custom_data_dir)
      PREFIX          = var.f5xc_aws_tgw_workload_subnet
      GATEWAY         = cidrhost(module.aws_subnet.aws_subnets[format("%s-aws-ec2-test-private-subnet-%s", var.project_prefix, var.project_suffix)]["cidr_block"], 1)
      GITEA_VERSION   = var.gitea_version
      GITEA_PASSWORD  = var.gitea_password
    }
  }
  aws_ec2_instance_script_template = var.aws_ec2_instance_script_template_file_name
  aws_ec2_instance_script_file     = var.aws_ec2_instance_script_file_name
  aws_az_name                      = var.aws_az
  aws_region                       = var.aws_region
  ssh_private_key                  = file(var.ssh_private_key_file)
  ssh_public_key                   = file(var.ssh_public_key_file)
  template_output_dir_path         = local.template_output_dir_path
  template_input_dir_path          = local.template_input_dir_path
  aws_ec2_network_interfaces       = [
    {
      create_eip      = true
      private_ips     = ["172.16.192.11"]
      security_groups = [module.aws_security_group_public.aws_security_group["id"]]
      subnet_id       = module.aws_subnet.aws_subnets[format("%s-aws-ec2-test-public-subnet-%s", var.project_prefix, var.project_suffix)]["id"]
      custom_tags     = merge({ "Owner" : var.owner }, local.custom_tags)
    },
    {
      create_eip      = false
      private_ips     = ["172.16.193.11"]
      security_groups = [module.aws_security_group_private.aws_security_group["id"]]
      subnet_id       = module.aws_subnet.aws_subnets[format("%s-aws-ec2-test-private-subnet-%s", var.project_prefix, var.project_suffix)]["id"]
      custom_tags     = merge({ "Owner" : var.owner }, local.custom_tags)
    }
  ]
  aws_ec2_instance_custom_data_dirs = [
    {
      name        = "instance_script"
      source      = "${local.template_output_dir_path}/${var.aws_ec2_instance_script_file_name}"
      destination = format("/tmp/%s", var.aws_ec2_instance_script_file_name)
    },
    {
      name        = "additional_custom_data"
      source      = abspath(var.custom_data_dir)
      destination = "/tmp"
    }
  ]
  custom_tags = local.custom_tags
  providers   = {
    aws = aws.default
  }
}

output "ec2_02" {
  value = module.ec2_02_interface_inline.aws_ec2_instance
}

output "script_template_file" {
  value = abspath("templates/${var.aws_ec2_instance_script_template_file_name}")
}

output "rendered_script_file" {
  value = "${local.template_output_dir_path}/${var.aws_ec2_instance_script_file_name}"
}

output "aws_subnet_ids" {
  value = module.aws_subnet.aws_subnets
}
````
