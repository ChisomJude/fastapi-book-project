provider "aws" {
  region = "us-east-1"  # Change to your preferred AWS region
}

resource "aws_security_group" "fastapi_sg" {
  name_prefix = "fastapi-sg-"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Allow SSH (Restrict in production)
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Allow HTTP traffic
  }

  ingress {
    from_port   = 8000
    to_port     = 8000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Allow FastAPI traffic (if accessing directly)
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "fastapi-security-group"
  }
}

resource "aws_instance" "fastapi_server" {
  ami           = "ami-0e1bed4f06a3b463d"  #  Ubuntu AMI for 22.04
  instance_type = "t2.medium"
  key_name      = "ubuntussh"  # Ensure this key exists, this is mine
  security_groups = [aws_security_group.fastapi_sg.name]

  tags = {
    Name = "fastapi-server"
  }

  user_data = <<-EOF
              #!/bin/bash
              set -e

              # Update and install dependencies
              apt update -y
              apt install -y python3-pip python3-venv nginx git

              # Create app directory and set permissions
              mkdir -p /var/www/book-app
              chown ubuntu:ubuntu /var/www/book-app
              cd /var/www/book-app

              # Clone your FastAPI repository
              git clone https://github.com/ChisomJude/fastapi-book-project.git .  # Replace with your repo
              
              # Set up virtual environment and install dependencies
              python3 -m venv venv
              source venv/bin/activate
              pip install -r requirements.txt

              # Create systemd service for FastAPI
              cat <<EOT > /etc/systemd/system/fastapi.service
              [Unit]
              Description=FastAPI application
              After=network.target

              [Service]
              ExecStart=/var/www/book-app/venv/bin/uvicorn main:app --host 0.0.0.0 --port 8000
              WorkingDirectory=/var/www/book-app
              Environment="PATH=/var/www/book-app/venv/bin"
              User=ubuntu
              Group=ubuntu
              Restart=always

              [Install]
              WantedBy=multi-user.target
              EOT

              # Reload systemd, enable and start FastAPI service
              systemctl daemon-reload
              systemctl enable fastapi.service
              systemctl start fastapi.service

              # Configure Nginx as a reverse proxy
              cat <<EOT > /etc/nginx/sites-available/fastapi
              server {
                  listen 80;
                  server_name _;

                  location / {
                      proxy_pass http://127.0.0.1:8000;
                      proxy_set_header Host \$host;
                      proxy_set_header X-Real-IP \$remote_addr;
                      proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
                      proxy_set_header X-Forwarded-Proto \$scheme;
                  }
              }
              EOT

              # Enable Nginx config
              ln -s /etc/nginx/sites-available/fastapi /etc/nginx/sites-enabled/
              rm -f /etc/nginx/sites-enabled/default
              systemctl restart nginx
  EOF
}

output "instance_public_ip" {
  value = aws_instance.fastapi_server.public_ip
}
