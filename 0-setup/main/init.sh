#!/bin/bash
# execute init.sh <project_id> 

project_id=$1

gcloud config set project $project_id
gcloud config set compute/region australia-southeast1

gcloud services enable compute.googleapis.com
gcloud services enable dns.googleapis.com
gcloud services enable servicenetworking.googleapis.com
gcloud services enable cloudresourcemanager.googleapis.com
gcloud services enable container.googleapis.com
# gcloud services enable artifactregistry.googleapis.com
