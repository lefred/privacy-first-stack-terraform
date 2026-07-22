# MariaDB Privacy-First Stack: deployment on Microsoft Azure

This is the directory to use to deploy the Privacy-First Stack in Microsoft Azure:

```
az login

az account show --query id --output tsv
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

[![Watch the video](https://i9.ytimg.com/vi/jauRdrVM-8k/sddefault.jpg?v=6a5a1feb&sqp=CMjA6NIG&rs=AOn4CLC-QewaC0WrWOexisCCT3UznYgx8Q)](https://youtu.be/60K4E3jO9dM)
