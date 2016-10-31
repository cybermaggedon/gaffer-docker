
Here's some template configuration files to run Gaffer on Kubernetes
in the Google cloud.  This template uses three ext4 disks in the cloud, the
configuration on AWS is slightly different.

```

  a=https://www.googleapis.com/auth
  proj=MY-PROJECT

  # Create cluster
  gcloud container --project ${proj} clusters create gaffer-cluster \
    --zone "us-east1-b" --machine-type "n1-standard-4" \
    --scopes "${a}/compute","${a}/devstorage.read_only","${a}/logging.write","${a}/monitoring","${a}/servicecontrol","${a}/service.management.readonly" \
    --num-nodes 3 --network "default" --enable-cloud-logging \
    --enable-cloud-monitoring


  # 25 GB disk for Gaffer Hadoop
  gcloud compute --project ${proj} disks create "hadoop-0000" \
  --size "25" --zone "us-east1-b" --type "pd-standard"

  # 10 GB disk for Gaffer Zookeeper
  gcloud compute --project ${proj} disks create "zookeeper-0000" \
  --size "10" --zone "us-east1-b" --type "pd-standard"

  # 1 GB disk for Gaffer Accumulo
  gcloud compute --project ${proj} disks create "accumulo-0000" \
      --size "1" --zone "us-east1-b" --type "pd-standard"

  # Get Kubernetes creds
  gcloud container clusters get-credentials gaffer-cluster \
      --zone us-east1-b --project ${proj}

  # Deploy
  kubectl apply -f gaffer-deployment.yaml
  kubectl apply -f gaffer-services.yaml

```
