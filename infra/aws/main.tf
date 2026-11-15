data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  azs = slice(data.aws_availability_zones.available.names, 0, 3)
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name                 = var.name
  cidr                 = var.vpc_cidr
  azs                  = local.azs
  private_subnets      = [for i in range(3) : cidrsubnet(var.vpc_cidr, 4, i)]
  public_subnets       = [for i in range(3) : cidrsubnet(var.vpc_cidr, 4, i + 8)]
  database_subnets     = [for i in range(3) : cidrsubnet(var.vpc_cidr, 4, i + 4)]
  enable_nat_gateway   = true
  single_nat_gateway   = false
  enable_dns_hostnames = true

  private_subnet_tags = { "kubernetes.io/role/internal-elb" = 1 }
  public_subnet_tags  = { "kubernetes.io/role/elb" = 1 }
}

module "ebs_csi_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name             = "${var.name}-ebs-csi"
  attach_ebs_csi_policy = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:ebs-csi-controller-sa"]
    }
  }
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.31"

  cluster_name    = var.name
  cluster_version = var.kubernetes_version
  vpc_id          = module.vpc.vpc_id
  subnet_ids      = module.vpc.private_subnets

  enable_cluster_creator_admin_permissions = true
  cluster_endpoint_public_access           = true

  cluster_addons = {
    coredns    = {}
    kube-proxy = {}
    vpc-cni = {
      configuration_values = jsonencode({ enableNetworkPolicy = "true" }) # VPC CNI enforces NetworkPolicy
    }
    aws-ebs-csi-driver = {
      service_account_role_arn = module.ebs_csi_irsa.iam_role_arn
    }
  }

  eks_managed_node_groups = {
    default = {
      instance_types = [var.node_instance_type]
      min_size       = var.min_nodes
      max_size       = var.max_nodes
      desired_size   = var.min_nodes
    }
  }
}

# ---- PostgreSQL (RDS) ----
resource "random_password" "db" {
  length  = 32
  special = false
}

resource "aws_security_group" "db" {
  name   = "${var.name}-db"
  vpc_id = module.vpc.vpc_id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [module.eks.node_security_group_id, aws_security_group.sandbox.id]
  }
}

resource "aws_db_instance" "postgres" {
  identifier                = "${var.name}-pg"
  engine                    = "postgres"
  engine_version            = "16"
  instance_class            = var.database_instance_class
  allocated_storage         = 50
  max_allocated_storage     = 500
  storage_type              = "gp3"
  storage_encrypted         = true
  multi_az                  = true
  db_subnet_group_name      = module.vpc.database_subnet_group_name
  vpc_security_group_ids    = [aws_security_group.db.id]
  username                  = "kuasar_admin"
  password                  = random_password.db.result
  backup_retention_period   = 14
  deletion_protection       = true
  skip_final_snapshot       = false
  final_snapshot_identifier = "${var.name}-pg-final"
}

# ---- Sandbox host ----
data "aws_ssm_parameter" "ubuntu" {
  name = "/aws/service/canonical/ubuntu/server/24.04/stable/current/amd64/hvm/ebs-gp3/ami-id"
}

resource "aws_security_group" "sandbox" {
  name   = "${var.name}-sandbox"
  vpc_id = module.vpc.vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.admin_cidrs
  }
  ingress {
    from_port   = 8080
    to_port     = 8090
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "sandbox" {
  ami                    = data.aws_ssm_parameter.ubuntu.value
  instance_type          = var.sandbox_instance_type
  subnet_id              = module.vpc.public_subnets[0]
  vpc_security_group_ids = [aws_security_group.sandbox.id]
  key_name               = var.key_pair_name
  user_data              = file("${path.module}/../sandbox-host/cloud-init.yaml")

  metadata_options {
    http_tokens = "required"
  }
  root_block_device {
    volume_size = 100
    volume_type = "gp3"
    encrypted   = true
  }
  tags = { Name = "${var.name}-sandbox" }
}

# The pods (NodePort bridge services) must be reachable from the sandbox host: allow it on the node security group.
resource "aws_security_group_rule" "nodeports_from_sandbox" {
  type                     = "ingress"
  security_group_id        = module.eks.node_security_group_id
  source_security_group_id = aws_security_group.sandbox.id
  protocol                 = "tcp"
  from_port                = 30101
  to_port                  = 30672
}
