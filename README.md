# PoC - Terraform and Google Container Engine

## DISCLAIMER

Heavily modified release by gruntwork-io
  - https://github.com/gruntwork-io/terraform-google-network
  - https://github.com/gruntwork-io/terraform-google-gke

## Requirements

Ensure the software listed in requirements are installed.

## Setup

Execute terraform command in folder '0-setup/main'

## Deploy

Execute terraform command in folder '0-deploy/main'

HELM
### Pending

remote state not done

helm not TF
  version
  rollback/forward
  devops integration

version 1/2 for dynamic content only

static and dynamic same containers - but seperate routes

https with cert manager termination at istioingress

http headers-> sso - claims

gcr container the required container images (latest, v1, v2)

desination rules and virtual services to be dynamically managed by devops ci/cd

move back setup.sh

private cluster

with lose firewall rules - real life would be more finely tuned

images dont actually appear
