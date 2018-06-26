#!/bin/sh
# variables 
REGION='us-east1'
NETWORK='example-vpc'
SUBNET='example-east'
MACHINETYPE='n1-standard-2'

#create a custom VPC associated with your GCP project. This VPC allows you to use non-default IP addressing, but does not include any default firewall rules:
gcloud compute networks create $NETWORK --subnet-mode custom

#Create a subnet within this VPC, and specify a region and IP range. For this tutorial, use 10.0.1.0/24 and the us-east1 region:
gcloud compute networks subnets create $SUBNET \
    --network $NETWORK --range 10.0.1.0/24 --region $REGION

#Reserve and store three static IP addresses.
#Reserve and store an address named nat-1 in the us-east1 region:
gcloud compute addresses create nat-1 --region $REGION

nat_1_ip=$(gcloud compute addresses describe nat-1 \
    --region $REGION --format='value(address)')

#Reserve and store an address named nat-2 in us-east1:
gcloud compute addresses create nat-2 --region $REGION

nat_2_ip=$(gcloud compute addresses describe nat-2 \
    --region $REGION --format='value(address)')

#Reserve and store an address named nat-3 in us-east1:
gcloud compute addresses create nat-3 --region $REGION
nat_3_ip=$(gcloud compute addresses describe nat-3 \
    --region $REGION --format='value(address)')

#Create three instance templates with reserved IPs.
#Copy the startup config:
gsutil cp gs://nat-gw-template/startup.sh .

#If you cannot access the startup script, copy it from the Startup script section.

#Create a nat-1 instance template:

gcloud compute instance-templates create nat-1 \
    --network $NETWORK --subnet $SUBNET --region $REGION --machine-type $MACHINETYPE --can-ip-forward --tags natgw \
    --metadata-from-file=startup-script=startup.sh --address $nat_1_ip

#Create a nat-2 instance template:
gcloud compute instance-templates create nat-2 \
    --network $NETWORK --subnet $SUBNET --region $REGION --machine-type $MACHINETYPE --can-ip-forward --tags natgw \
    --metadata-from-file=startup-script=startup.sh  --address $nat_2_ip

#Create a nat-3 instance template:
gcloud compute instance-templates create nat-3 \
    --network $NETWORK --subnet $SUBNET --region $REGION --machine-type $MACHINETYPE --can-ip-forward --tags natgw \
    --metadata-from-file=startup-script=startup.sh --address $nat_3_ip

#The n1-standard-2 machine type has two vCPUs and can use up to 4 Gbps of network bandwidth.
#If you need more bandwidth, you might want to choose a different host.
#Bandwidth scales at 2 Gbps per vCPU, up to 16 Gbps on an 8vCPU host.

#Create a health check to monitor responsiveness:
gcloud compute health-checks create http nat-health-check --check-interval 30 \
    --healthy-threshold 1 --unhealthy-threshold 5 --request-path /health-check

gcloud compute firewall-rules create "natfirewall" \
    --network $NETWORK --allow tcp:80 --target-tags natgw \
    --source-ranges "130.211.0.0/22","35.191.0.0/16"
#If a system fails and can't respond to HTTP traffic, it is restarted.
#In this case, since you need a project, you can use an existing project or create a new one.

#Create an instance group for each NAT gateway:

gcloud compute instance-groups managed create nat-1 --size=1 --template=nat-1 --zone=us-east1-b
gcloud compute instance-groups managed create nat-2 --size=1 --template=nat-2 --zone=us-east1-c
gcloud compute instance-groups managed create nat-3 --size=1 --template=nat-3 --zone=us-east1-d

#Set up autohealing to restart unresponsive NAT gateways:

gcloud beta compute instance-groups managed set-autohealing nat-1 \
    --health-check nat-health-check --initial-delay 120 --zone us-east1-b
nat_1_instance=$(gcloud compute instances list |awk '$1 ~ /^nat-1/ { print $1 }')

gcloud beta compute instance-groups managed set-autohealing nat-2 \
    --health-check nat-health-check --initial-delay 120 --zone us-east1-c
nat_2_instance=$(gcloud compute instances list |awk '$1 ~ /^nat-2/ { print $1 }')

gcloud beta compute instance-groups managed set-autohealing nat-3 \
    --health-check nat-health-check --initial-delay 120 --zone us-east1-d
nat_3_instance=$(gcloud compute instances list |awk '$1 ~ /^nat-3/ { print $1 }')

#Add default routes to your instances:
gcloud compute routes create natroute1 --network $NETWORK --destination-range 0.0.0.0/0 \
    --tags no-ip --priority 800 --next-hop-instance-zone us-east1-b \
    --next-hop-instance $nat_1_instance
gcloud compute routes create natroute2 --network $NETWORK --destination-range 0.0.0.0/0 \
    --tags no-ip --priority 800 --next-hop-instance-zone us-east1-c \
    --next-hop-instance $nat_2_instance
gcloud compute routes create natroute3 --network $NETWORK --destination-range 0.0.0.0/0 \
    --tags no-ip --priority 800 --next-hop-instance-zone us-east1-d \
    --next-hop-instance $nat_3_instance

#Tag the instances that you want to use the NAT:

#gcloud compute instances add-tags <natted-servers> --tags no-ip




