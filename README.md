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
This the main reason fot breaking the deliverable into the parts - Setup and Deploy, but delivering it TF, since the exercise was to get familiar with TF and GKE.

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
PS: while a volume has been mounted to the static container, they will not show as the container itself has not been configured to do so.

5. Container Versions
Static content has a single version released.
Dynamic content has two versions released.
v1 is running, but access has been locked to all
v2 is permitted to users with the text "tester" that needs to be part of the header
The principle being after logging the user's oauth scopes will be in added to the header and would be used ensure only authenticated and authorised users are permitted to view v2 of the site.

6. Cluster Provisioning
have built a private cluster and put the container engine behind a cloud nat.
and at the moment have put in place very lose firewall rules.

7. Cloud CDN
to give the required millisecond respond Clound CDN can be activated.

## Assumption

1. sub second response time are being delivered through cloud cdn

2. and continuity of delivery is being met by the container platform and node/pod scalability

3. since no fail over time was mentioned, 5 second timeout has been configured in istio

## Known Issues (issues to rectify with more time available)

1. known issues, static content does not show

2. the develop plan is ran immediately after setup, will fail. needs to be another time to succeed. but then again TF is the wrong resource for this operation.

3. loose firewall configuration

4. incorrect container images, have deployed hello-app with different tags as it serves the demo purpose.
have used the image here [https://github.com/GoogleCloudPlatform/kubernetes-engine-samples/tree/master/hello-app] and pushed it to GCR as hello-app tagged as latest,v1,v2

5. Container image and aseet maangement (zip file) to be managed a devops ci/cd pipeline

6, deploy plan has locals that really should be plan variables