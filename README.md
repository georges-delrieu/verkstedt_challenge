## Verkstedt Challenge
This repository maps out the deployment of a dockerized NGINX server on AWS using Terraform.
The final infrastructure of this server features

- A custom Virtual Private Cloud (VPC)
- Two shareable subnets with different availability zones
- An application load balancer

The webserver can be access through the load balancer DNS [here](http://load-balancer-1337580158.eu-west-3.elb.amazonaws.com/) 

The full architecture is detailed below:
![my_image](schematic_verkstedt.png)
