# EC2

Terraform to create AWS EC2 instance

## Usage

- Clone this repo with `git clone --recurse-submodules https://github.com/cklewar/aws-ec2`
- Enter repository directory with `cd ec2`
- Obtain F5XC API certificate file from Console and save it to `cert` directory
- Pick and choose from below examples and add mandatory input data and copy data into file `main.py.example`.
- Rename file __main.tf.example__ to __main.tf__ with `rename main.py.example main.py`
- Change backend settings in `versions.tf` file to fit your environment needs
- Initialize with `terraform init`
- Apply with `terraform apply -auto-approve` or destroy with `terraform destroy -auto-approve`

## EC2 module usage example

````hcl
````