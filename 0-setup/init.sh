#!/bin/bash
# execute run.sh <project_id> <deploy_service_account_name> <node_service_account_name>

project_id=$1
deploy_service_account_name=$2
node_service_account_name=$3

sed -i "s#REPLACE_project_id#$project_id#g"                                 0-setup/terraform.tfvars 
sed -i "s#REPLACE_deploy_service_account#$deploy_service_account_name#g"    0-setup/terraform.tfvars 
sed -i "s#REPLACE_node_service_account#$node_service_account_name#g"        0-setup/terraform.tfvars 

gcloud config set project $project_id
gcloud config set compute/region australia-southeast1

gcloud services enable compute.googleapis.com
gcloud services enable servicenetworking.googleapis.com
gcloud services enable cloudresourcemanager.googleapis.com
gcloud services enable container.googleapis.com

gcloud iam service-accounts create $deploy_service_account_name || true
gcloud projects add-iam-policy-binding $project_id --member serviceAccount:$deploy_service_account_name@$project_id.iam.gserviceaccount.com --role roles/container.admin
gcloud projects add-iam-policy-binding $project_id --member serviceAccount:$deploy_service_account_name@$project_id.iam.gserviceaccount.com --role roles/compute.admin
gcloud projects add-iam-policy-binding $project_id --member serviceAccount:$deploy_service_account_name@$project_id.iam.gserviceaccount.com --role roles/iam.serviceAccountUser
gcloud projects add-iam-policy-binding $project_id --member serviceAccount:$deploy_service_account_name@$project_id.iam.gserviceaccount.com --role roles/iam.serviceAccountTokenCreator
gcloud projects add-iam-policy-binding $project_id --member serviceAccount:$deploy_service_account_name@$project_id.iam.gserviceaccount.com --role roles/resourcemanager.projectIamAdmin

if [ ! -f "0-setup/$deploy_service_account_name-keyfile.json" ]; then
    gcloud iam service-accounts keys create "0-setup/$deploy_service_account_name-keyfile.json" --iam-account=$deploy_service_account_name@$project_id.iam.gserviceaccount.com
fi


gsutil mb -p $project_id -c regional -l australia-southeast1 gs://$project_id-terraform-state/ || true
gsutil versioning set on gs://$project_id-terraform-state/
gsutil iam ch serviceAccount:$deploy_service_account_name@$project_id.iam.gserviceaccount.com:legacyBucketWriter gs://$project_id-terraform-state/

gcloud iam service-accounts create $node_service_account_name || true
