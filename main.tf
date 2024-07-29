resource "tls_private_key" "pk" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "kp" {
  key_name   = "kube-demo" 
  public_key = tls_private_key.pk.public_key_openssh

  provisioner "local-exec" { 
    command = "echo '${tls_private_key.pk.private_key_pem}' > kube-demo.pem"

  }
}
resource "aws_security_group" "my-ec2" {
  name        = "Jenkins-Security Group"
  description = "Open 22,443,80,8080"

  ingress = [
    for port in [22, 80,8080, 443] : {
      description      = "TLS from VPC"
      from_port        = port
      to_port          = port
      protocol         = "tcp"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = []
      prefix_list_ids  = []
      security_groups  = []
      self             = false
    }
  ]

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Jenkins server"
  }
}


resource "aws_instance" "web" {
  ami                    = "ami-0e001c9271cf7f3b9" # change your ami name 
  instance_type          = "t2.medium"
  key_name               = "kube-demo"
  vpc_security_group_ids = [aws_security_group.my-ec2.id]
  depends_on = [aws_key_pair.kp]
  tags = {
    Name = "Jenkins server"
  }
  root_block_device {
    volume_size = 30
  }

  provisioner "local-exec" {
     command = "ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -i ${aws_instance.web.public_ip}, --private-key kube-demo.pem -u ubuntu jenkins.yaml"
 }
}
output "pubip" {
  value = aws_instance.web.public_ip

}
