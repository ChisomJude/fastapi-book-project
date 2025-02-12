provider "aws" {
  region = "us-east-1"  
}

resource "aws_instance" "nginx_server" {
  ami                    = "ami-0e1bed4f06a3b463d"  # Ubuntu 22.04 LTS 
  instance_type          = "t2.medium"
  key_name               = "ubuntussh"  
  associate_public_ip_address = true
  security_groups        = [aws_security_group.nginx_sg.name]

  user_data = <<-EOF
    #!/bin/bash
    sudo apt update -y
    sudo apt install -y nginx git
    sudo mkdir -p /var/www/book-app
    sudo chown $USER:$USER /var/www/book-app
    cd /var/www/book-app

    sudo systemctl enable nginx
    sudo systemctl start nginx

    # Configure Nginx as a reverse proxy
    cat <<EOT | sudo tee /etc/nginx/sites-available/default
    server {
        listen 80;
        location / {
            proxy_pass http://localhost:8000;  
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        }
    }
    EOT

    sudo systemctl restart nginx
  EOF

  tags = {
    Name = "Terraform-Nginx-Server"
  }
}

resource "aws_security_group" "nginx_sg" {
  name        = "nginx_sg"
  description = "Allow SSH and HTTP"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Restrict in production
  }

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
