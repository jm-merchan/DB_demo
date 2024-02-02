# https://github.com/hashicorp/learn-terraform-rds/blob/main/main.tf

resource "aws_db_subnet_group" "boundary_demo" {
  name       = "boundary_demo"
  subnet_ids = [aws_subnet.private1.id, aws_subnet.private2.id]

  tags = {
    Name = "boundary_demo"
  }
}

resource "aws_security_group" "rds" {
  name   = "boundary_demo_rds"
  vpc_id = aws_vpc.vpc.id

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [var.aws_vpc_cidr, var.hvn_cidr]
  }

  egress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "boundary_demo_rds"
  }
}

resource "aws_db_parameter_group" "boundary_demo" {
  name   = "boundarydemo"
  family = "postgres13" #"postgres16"

  parameter {
    name  = "log_connections"
    value = "1"
  }
  parameter {
    name  = "rds.force_ssl"
    value = "0"
  }
}

resource "aws_db_instance" "boundary_demo" {
  identifier             = "boundarydemo"
  instance_class         = "db.t3.micro"
  allocated_storage      = 5
  engine                 = "postgres"
  engine_version         = "13.7" #"16.1"
  username               = var.db_username
  password               = var.password
  db_subnet_group_name   = aws_db_subnet_group.boundary_demo.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  parameter_group_name   = aws_db_parameter_group.boundary_demo.name
  publicly_accessible    = false
  skip_final_snapshot    = true
}