#!/bin/bash

cd $(dirname "$0")

terraform init
terraform plan -out plan.tfpan
# terraform apply plan.tfpan

cd-