
# Versão minima provedor AWS
terraform {

  required_providers {

    aws = "5.23.1"
  }
}

# Configurando a região do meu provedor 
provider "aws" {

  region = "us-east-1"
}

/* 
  Este bloco cria uma Virtual Private Cloud (VPC) com o bloco CIDR "10.0.0.0/16" 
  e habilita a resolução de nomes DNS para as instâncias na VPC
*/
resource "aws_vpc" "vpc-dev" {

  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true

}

/*
   Aqui você está criando quatro subnets: duas públicas (em "us-east-1a" e "us-east-1b") 
   e duas privadas (também em "us-east-1a" e "us-east-1b").
*/
resource "aws_subnet" "public_subnet_a" {

  vpc_id            = aws_vpc.vpc-dev.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-1a"
}

resource "aws_subnet" "public_subnet_b" {

  vpc_id            = aws_vpc.vpc-dev.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "us-east-1b"
}

resource "aws_subnet" "private_subnet_a" {

  vpc_id            = aws_vpc.vpc-dev.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "us-east-1a"
}

resource "aws_subnet" "private_subnet_b" {

  vpc_id            = aws_vpc.vpc-dev.id
  cidr_block        = "10.0.4.0/24"
  availability_zone = "us-east-1b"
}

/* 
  Este bloco cria uma instância EC2 usando a AMI especificada, 
  o tipo de instância "t2.micro" e coloca a instância na subnet privada "private_subnet_a".
*/
resource "aws_instance" "webserver" {

  ami           = "ami-0fc5d935ebf8bc3bc"
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.private_subnet_a.id
}

/* 
  Criando uma instância de banco de dados RDS MySQL com as configurações especificadas, 
  incluindo a alocação de armazenamento, a versão do MySQL, e as credenciais do banco de dados. 
  O banco de dados está associado ao grupo de subnets "db_subnet".
*/
resource "aws_db_instance" "banco" {

  allocated_storage    = 10
  engine               = "mysql"
  engine_version       = "5.7"
  instance_class       = "db.t2.micro"
  username             = "admin"
  password             = "UL`YabTkm:"
  skip_final_snapshot  = true
  db_subnet_group_name = aws_db_subnet_group.db_subnet.id
}

/*
  Cria um grupo de subnets do RDS com as duas subnets privadas
*/
resource "aws_db_subnet_group" "db_subnet" {

  name       = "dbsubnet"
  subnet_ids = [aws_subnet.private_subnet_a.id, aws_subnet.private_subnet_b.id]
}

/*
  Aqui você está criando um Elastic IP (EIP) para a NAT Gateway. 
  Este IP será usado para permitir que instâncias em suas subnets privadas acessem a internet.
*/
resource "aws_eip" "nat" {

  vpc        = true
  depends_on = [aws_internet_gateway.igw]
}

/*
  Este bloco cria um Internet Gateway e o associa a VPC para permitir que instâncias na VPC se comuniquem com a Internet.
*/
resource "aws_internet_gateway" "igw" {

  vpc_id = aws_vpc.vpc-dev.id
}

/*
  Aqui você está criando uma NAT Gateway na subnet privada "private_subnet_a" 
  usando o Elastic IP que você criou anteriormente.
*/
resource "aws_nat_gateway" "nat_gw" {

  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.private_subnet_a.id

  depends_on = [aws_internet_gateway.igw]
}

/*
  Este bloco cria uma tabela de roteamento que redireciona todo o tráfego para a NAT Gateway, 
  permitindo que as instâncias em suas subnets privadas acessem a internet de forma controlada.
*/
resource "aws_route_table" "router" {

  vpc_id = aws_vpc.vpc-dev.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.nat_gw.id
  }
}

/*
  Aqui você está associando a tabela de roteamento criada anteriormente à subnet privada "private_subnet_a".
*/
resource "aws_route_table_association" "assoc" {

  subnet_id      = aws_subnet.private_subnet_a.id
  route_table_id = aws_route_table.router.id
}