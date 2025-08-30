
#----- EC2 Resource Creation
locals {
  name_prefix = "wilson"
}

# Get the latest Amazon Linux 2 AMI
data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

# Reference the existing VPC and public subnet using data sources or variables if they are not in the same file.
# Example:
data "aws_vpc" "existing" {
  filter {
    name   = "tag:Name"
    values = ["shared-vpc"]
  }
}

data "aws_subnet" "public" {
  filter {
    name   = "tag:Name"
    values = ["shared-vpc-public*"]
  }
  vpc_id = data.aws_vpc.existing.id
  # Add the Availability Zone filter
  filter {
    name   = "availability-zone"
    values = ["us-east-1a"] # Replace with your desired AZ
  }
}

#Create Dynamo Table
resource "aws_dynamodb_table" "example_table" {
  name           = "${local.name_prefix}-example-table"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "UserId"

  attribute {
    name = "UserId"
    type = "S"
  }

  tags = {
    Name = "${local.name_prefix}-dynamodb-table"
  }
}

# Create Security Group
resource "aws_security_group" "sg_example" {
  name        = "${local.name_prefix}-sg"
  description = "Allow inbound traffic"
  #You need to provide the vpc_id here
  vpc_id      = "vpc-037beb3e76128a4d8"

  ingress {
    from_port   = 22
    to_port     = 22
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

# Create the EC2 instance in the public subnet
resource "aws_instance" "web_server" {
  ami                         = data.aws_ami.amazon_linux_2.id
  instance_type               = "t2.micro"
  #You must provide the subnet_id of your public subnet
  subnet_id                   = data.aws_subnet.public.id
  vpc_security_group_ids      = [aws_security_group.sg_example.id]
  associate_public_ip_address = true

  # Attach the IAM instance profile by referencing its name
  iam_instance_profile = aws_iam_instance_profile.profile_example.name

  tags = {
    Name = "${local.name_prefix}-ec2"
  }
}


#-----------IAM Policy Creation-----------


resource "aws_iam_role" "role_example" {
 name = "${local.name_prefix}-role-example"


 assume_role_policy = jsonencode({
   Version = "2012-10-17"
   Statement = [
     {
       Action = "sts:AssumeRole"
       Effect = "Allow"
       Sid    = ""
       Principal = {
         Service = "ec2.amazonaws.com"
       }
     },
   ]
 })
}

data "aws_iam_policy_document" "policy_example" {
 statement {
   effect    = "Allow"
   actions   = ["ec2:Describe*"]
   resources = ["*"]
 }
 statement {
   effect    = "Allow"
   actions   = ["s3:ListBucket", "s3:ListAllMyBuckets"]

      resources = ["*"]
 }
 statement {
    effect    = "Allow"
    actions   = [
      "dynamodb:ListTables", # Permission to list all tables in the account
      "dynamodb:Scan"        # Permission to read all items in a table
    ]
    resources = ["*"] # Applies to all DynamoDB tables
  }
}

resource "aws_iam_policy" "policy_example" {
 name = "${local.name_prefix}-policy-example"


 ## Option 1: Attach data block policy document
 policy = data.aws_iam_policy_document.policy_example.json


}

resource "aws_iam_role_policy_attachment" "attach_example" {
 role       = aws_iam_role.role_example.name
 policy_arn = aws_iam_policy.policy_example.arn
}


resource "aws_iam_instance_profile" "profile_example" {
 name = "${local.name_prefix}-profile-example"
 role = aws_iam_role.role_example.name
}
