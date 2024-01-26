
resource "aws_security_group" "rds-sg" {
  name        = "${var.r_prefix}-rds-sg"
  description = "Allow db inbound traffic and all outbound traffic"
  vpc_id      = module.vpc.vpc_id
  
  tags = {
    Name = "${var.r_prefix}-rds-sg"
  }
}
resource "aws_vpc_security_group_ingress_rule" "rds-eks-access" {
  ip_protocol = "tcp"
  from_port   = 5432
  to_port     = 5432
  security_group_id = aws_security_group.rds-sg.id
  referenced_security_group_id = module.eks.node_security_group_id
}

resource "aws_db_instance" "default" {
  identifier              = "${var.r_prefix}-rds"
  allocated_storage       = 10
  db_name                 = "skillupdb"
  engine                  = "postgres"
  engine_version          = "15.4"
  instance_class          = "db.t3.micro"
  username                = "foo"
  password                = "foobarbaz"
  multi_az                = false
  deletion_protection     = false
  skip_final_snapshot     = true
  db_subnet_group_name    = module.vpc.database_subnet_group_name
  vpc_security_group_ids  = [aws_security_group.rds-sg.id]
  tags = {
    Name = "dstorozhenko-skillup-rds"
  }
}
# psql --host=dstorozhenko-skillup-rds.ctneloibxyyb.us-east-1.rds.amazonaws.com --port=5432 --username=foo --password -d skillupdb