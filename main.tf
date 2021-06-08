######## Base Components #########
provider "aws" {
  region  = "eu-west-3" 
}

resource "aws_ecr_repository" "verkstedt_container" {
  name = "verkstedt-container" 
}

resource "aws_ecs_cluster" "verkstedt_cluster" {
  name = "verkstedt-cluster"
}

resource "aws_vpc" "vpc" {
    cidr_block = "10.0.0.0/24"
    enable_dns_support   = true
    enable_dns_hostnames = true
    tags       = {
        Name = "Custom VPC"
    }
}

resource "aws_internet_gateway" "internet_gateway" {
    vpc_id = aws_vpc.vpc.id
}

resource "aws_subnet" "pub_subnet1" {
    vpc_id                  = aws_vpc.vpc.id
    cidr_block              = "10.0.0.0/25"
    availability_zone       = "eu-west-3a"
}

resource "aws_subnet" "pub_subnet2" {
    vpc_id                  = aws_vpc.vpc.id
    cidr_block              = "10.0.0.128/25"
    availability_zone       = "eu-west-3b"

}

resource "aws_route_table" "public" {
    vpc_id = aws_vpc.vpc.id

    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.internet_gateway.id
    }
}

resource "aws_route_table_association" "route_table_association1" {
    subnet_id      = aws_subnet.pub_subnet1.id
    route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "route_table_association2" {
    subnet_id      = aws_subnet.pub_subnet2.id
    route_table_id = aws_route_table.public.id
}

########## ECS ###########
resource "aws_ecs_task_definition" "spinning_container" {
  family                   = "spinning_container" 
  container_definitions    = <<DEFINITION
  [
    {
      "name": "spinning_container",
      "image": "${aws_ecr_repository.verkstedt_container.repository_url}",
      "essential": true,
      "portMappings": [
        {
          "containerPort": 80,
          "hostPort": 80
        }
      ],
      "memory": 512,
      "cpu": 256
    }
  ]
  DEFINITION
  requires_compatibilities = ["FARGATE"] 
  network_mode             = "awsvpc"    
  memory                   = 512         
  cpu                      = 256         
  execution_role_arn       = "${aws_iam_role.ecsTaskExecutionRole.arn}"
}

resource "aws_ecs_service" "verkstedt_service" {
  name            = "verkstedt-service"                             
  cluster         = "${aws_ecs_cluster.verkstedt_cluster.id}"             
  task_definition = "${aws_ecs_task_definition.spinning_container.arn}" 
  launch_type     = "FARGATE"
  desired_count   = 2

  load_balancer {
    target_group_arn = "${aws_lb_target_group.target_group.arn}" 
    container_name   = "${aws_ecs_task_definition.spinning_container.family}"
    container_port   = 80 
  }

  network_configuration {
    subnets = ["${aws_subnet.pub_subnet1.id}","${aws_subnet.pub_subnet2.id}"]
    assign_public_ip = true 
    security_groups  = ["${aws_security_group.service_security_group.id}"]
    
  }
}

resource "aws_security_group" "service_security_group" {
  vpc_id = aws_vpc.vpc.id
  ingress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    security_groups = ["${aws_security_group.load_balancer_security_group.id}"]
  }

  egress {
    from_port   = 0 
    to_port     = 0 
    protocol    = "-1" 
    cidr_blocks = ["0.0.0.0/0"] 
  }
}

########## IAM ###########
resource "aws_iam_role" "ecsTaskExecutionRole" {
  name               = "ecsTaskExecutionRole"
  assume_role_policy = "${data.aws_iam_policy_document.assume_role_policy.json}"
}

data "aws_iam_policy_document" "assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy_attachment" "ecsTaskExecutionRole_policy" {
  role       = "${aws_iam_role.ecsTaskExecutionRole.name}"
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

########## ALB ###########
resource "aws_alb" "application_load_balancer" {
  name               = "load-balancer" 
  load_balancer_type = "application"
  subnets = ["${aws_subnet.pub_subnet1.id}","${aws_subnet.pub_subnet2.id}"]
  security_groups = ["${aws_security_group.load_balancer_security_group.id}"]
}

resource "aws_security_group" "load_balancer_security_group" {
  vpc_id = aws_vpc.vpc.id
  ingress {
    from_port   = 80 
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] 
  }

  egress {
    from_port   = 0 
    to_port     = 0 
    protocol    = "-1"  
    cidr_blocks = ["0.0.0.0/0"] 
  }
}

resource "aws_lb_target_group" "target_group" {
  name        = "target-group"
  port        = 80
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = "${aws_vpc.vpc.id}"
  health_check {
    matcher = "200,301,302"
    path = "/"
  }
}

resource "aws_lb_listener" "listener" {
  load_balancer_arn = "${aws_alb.application_load_balancer.arn}"
  port              = "80"
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = "${aws_lb_target_group.target_group.arn}"
  }
}

########## RAM ###########
resource "aws_ram_resource_share" "sharing_ec2" {
  name                      = "sharing_ec2"
  allow_external_principals = true

}

# resource "aws_ram_principal_association" "authorized_principal" {
#   principal          = "111111111111" # Replace with Amazon ID of external principal
#   resource_share_arn = aws_ram_resource_share.sharing_ec2.arn
# }


# resource "aws_ram_resource_association" "sharing_sub1" {
#   resource_arn       = aws_subnet.pub_subnet1.arn
#   resource_share_arn = aws_ram_resource_share.sharing_ec2.arn
# }