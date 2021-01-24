#!/bin/bash
# execute run.sh <project_id> <deploy_service_account_name> <node_service_account_name>

project_id=$1
deploy_service_account_name=$2
node_service_account_name=$3

gcloud config set project $project_id
gcloud config set compute/zone australia-southeast1

gcloud services enable compute.googleapis.com
gcloud services enable servicenetworking.googleapis.com
gcloud services enable cloudresourcemanager.googleapis.com
gcloud services enable container.googleapis.com

gcloud iam service-accounts create $deploy_service_account_name
gcloud projects add-iam-policy-binding $project_id --member serviceAccount:$deploy_service_account_name@$project_id.iam.gserviceaccount.com --role roles/container.admin
gcloud projects add-iam-policy-binding $project_id --member serviceAccount:$deploy_service_account_name@$project_id.iam.gserviceaccount.com --role roles/compute.admin
gcloud projects add-iam-policy-binding $project_id --member serviceAccount:$deploy_service_account_name@$project_id.iam.gserviceaccount.com --role roles/iam.serviceAccountUser
gcloud projects add-iam-policy-binding $project_id --member serviceAccount:$deploy_service_account_name@$project_id.iam.gserviceaccount.com --role roles/iam.serviceAccountTokenCreatorgcloud projects add-iam-policy-binding $project_id --member serviceAccount:$deploy_service_account_name@$project_id.iam.gserviceaccount.com --role roles/resourcemanager.projectIamAdmin
gcloud iam service-accounts keys create $deploy_service_account_name-keyfile.json --iam-account=$deploy_service_account_name@$project_id.iam.gserviceaccount.com


gsutil mb -p $project_id -c regional -l australia-southeast1 gs://$project_id-terraform-state/
gsutil versioning set on gs://$project_id-terraform-state/
gsutil iam ch serviceAccount:$deploy_service_account_name@$project_id.iam.gserviceaccount.com:legacyBucketWriter gs://$project_id-terraform-state/

gcloud iam service-accounts create $deploy_service_account_name
