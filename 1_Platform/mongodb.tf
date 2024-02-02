# Create DocumentDB subnet group
resource "aws_docdb_subnet_group" "docdb_subnet_group" {
  name       = "docdb-subnet-group"
  subnet_ids = [aws_subnet.private1.id, aws_subnet.private2.id]

  tags = {
    Name = "docdb-subnet-group"
  }
}

resource "aws_docdb_cluster" "docdb" {
  cluster_identifier      = "docdb-cluster"
  master_username         = var.db_username
  master_password         = var.password
  backup_retention_period = 5
  preferred_backup_window = "07:00-09:00"
  skip_final_snapshot     = true
  vpc_security_group_ids  = [aws_security_group.privatesg.id]
  db_subnet_group_name    = aws_docdb_subnet_group.docdb_subnet_group.name
  port = 27017
}

resource "aws_docdb_cluster_instance" "docdb_node" {
  count              = 2
  identifier         = "docdb-node-${count.index}"
  cluster_identifier = aws_docdb_cluster.docdb.id
  instance_class     = "db.t3.medium"
  tags = {
    name         = format("%s_docdb_node_%d", "DocumentDB", count.index)
  }
}