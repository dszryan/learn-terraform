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

### Design Discussion

1. Release Management
Release management required a DevOps oriented CI/CD stack, that should use Helm to release containers to the environment.
Over here i have used Terraform (TF) as a proof of concept to show it can be done, but it is NOT the appropriate tool for the job.
Why?
Helm keep an instance of container that was release to the environment, and rolbacks are very to manage (Not so with TF)
This the main reason fot breaking the deliverable into the parts - Setup and Deploy

2. Remote State
Ideally the state of the terraform should be kept in a share enviroment, to that multiple engineers can manage the environment.
This has not been completed, since it has senitive data that should be kept encrypted.

3. Transport security
All HTTP traffic should be TLS encrypted over the internet, ideally this should be accomplished by using a cert-manager integrated with Istio.
This would require a domain name delegation, which has not been completed.

4. Containers
The containers used are the same (google-sample/hello-app) that has been labelled and tagged differently.
And istio has been used to route the traffic based on url.
  - http://<ip_adddress> has been delivered by the 'dynamic-content' artifacts
  - http://<ip_adddress>/static has been delivered by the 'static-content' artifacrs
NB: the content of "1-deploy/artifact" is copied to the container, but nginx has not been configued to show the static content

5. Container Versions
Dynamic content has two versions released.
v1 is running, but access has been locked to all
v2 is permitted to users with the text "tester" that needs to be part of the header


move back setup.sh

private cluster

with lose firewall rules - real life would be more finely tuned

images dont actually appear

no sticky sessions

deploy - fast and 

## Known Issues

