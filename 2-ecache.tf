
resource "aws_security_group" "ecache-sg" {
  name        = "${var.r_prefix}-ecache-sg"
  description = "Allow ecache inbound traffic and all outbound traffic"
  vpc_id      = module.vpc.vpc_id
  
  tags = {
    Name = "${var.r_prefix}-ecache-sg"
  }
}
resource "aws_vpc_security_group_ingress_rule" "ecache-eks-access" {
  ip_protocol = "tcp"
  from_port   = 6379
  to_port     = 6379
  security_group_id = aws_security_group.ecache-sg.id
  referenced_security_group_id = module.eks.node_security_group_id
}

resource "aws_elasticache_replication_group" "default" {
  replication_group_id        = "dstorozhenko-skillup-redis"
  description                 = "dstorozhenko skillup"
  engine                      = "redis"
  node_type                   = "cache.t2.micro"
  parameter_group_name        = "default.redis7.cluster.on"
  engine_version              = "7.1"
  port                        = 6379
  subnet_group_name           = module.vpc.elasticache_subnet_group_name
  security_group_ids          = [aws_security_group.ecache-sg.id]
  automatic_failover_enabled  = true
  num_node_groups             = 2
  replicas_per_node_group     = 1
}