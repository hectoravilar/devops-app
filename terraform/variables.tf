resource "aws_instance" "web" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t2.micro"
  subnet_id     = "subnet-12345"

  tags = {
    Environment = "DevOps"
    Name        = "docflow-web-instance"
  }
}
variable "environment" {
  type        = string
  description = "Deployment environment name"
  default     = "dev"
}
