## Verkstedt Challenge
This repository maps out the deployment of a dockerized NGINX server on AWS using Terraform.
The final infrastructure of this server features

- A custom Virtual Private Cloud (VPC)
- Two shareable subnets with different availability zones
- An application load balancer

The full architecture is detailed below:


![my_image](schematic_verkstedt.png)


## Replayability
To replicate this build, you need to meet three requirements:
- Having Terraform installed and in path
- Having Docker installed and in path
- An AWS account, and the CLI installed and in path

With this, all you need to do is run the following:

```sh
terraform init
terraform apply
```

The webserver can be accessed through the load balancer DNS outputted by the above code (it takes a few minutes)
