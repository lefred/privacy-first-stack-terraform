# MariaDB Privacy-First Stack: deployment on GCP

This is the directory to use to deploy the Privacy-First Stack in Google Cloud Platform:

You need to create a project in https://console.cloud.google.com/, here I called it `privacy-first-stack`
and then you need to login and enable the compute API service for your project:

```
gcloud init

gcloud auth application-default login

gcloud config set project privacy-first-stack

gcloud services enable compute.googleapis.com \
  --project=privacy-first-stack
```

And now you can prepare your terraform environment and deploy it:

```
cp terraform.tfvars.example terraform.tfvars
-- edit terraform.tvars with your info
terraform init
terraform plan
terraform apply
```

## Demo

Click to play on Youtube

[![Watch the video](https://i9.ytimg.com/vi/OLfXcKT_VT4/sddefault.jpg?v=6a5a409b&sqp=COz_6NIG&rs=AOn4CLCIlRKuC-D8Le13Iif76uGN70bPmg)](https://youtu.be/OLfXcKT_VT4)
