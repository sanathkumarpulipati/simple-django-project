data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

data "aws_ami" "windows_2022" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["Windows_Server-2022-English-Full-Base-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# --- Security Groups ---
# ALB SG: allow 80 from anywhere
resource "aws_security_group" "alb_sg" {
  name_prefix = "win-alb-"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "HTTP from anywhere"
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

# Instance SG: allow port 5000 from ALB only, and RDP from your IP
resource "aws_security_group" "instance_sg" {
  name_prefix = "win-app-"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description     = "App traffic from ALB"
    from_port       = 5000
    to_port         = 5000
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  ingress {
    description = "RDP"
    from_port   = 3389
    to_port     = 3389
    protocol    = "tcp"
    cidr_blocks = [var.allowed_rdp_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# --- Windows EC2 ---
resource "aws_instance" "win" {
  ami                    = data.aws_ami.windows_2022.id
  instance_type          = "t3.medium"
  key_name               = var.key_name
  subnet_id              = data.aws_subnets.default.ids[0]
  vpc_security_group_ids = [aws_security_group.instance_sg.id]
  associate_public_ip_address = true

  # Run once at first boot
  user_data = templatefile("${path.module}/userdata.ps1.tftpl", {
    repo_url       = var.repo_url
    branch         = var.branch
    app_dir        = var.app_dir
    app_start_cmd  = var.app_start_cmd
  })

  tags = {
    Name = "windows-python-app"
  }
}

# --- ALB + TG + Listener ---
resource "aws_lb" "alb" {
  name               = "win-python-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = data.aws_subnets.default.ids
}

resource "aws_lb_target_group" "tg" {
  name     = "win-python-tg"
  port     = 5000
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.default.id
  target_type = "instance"

  health_check {
    path                = "/"
    protocol            = "HTTP"
    port                = "5000"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    interval            = 30
    timeout             = 5
    matcher             = "200-399"
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg.arn
  }
}

resource "aws_lb_target_group_attachment" "attach" {
  target_group_arn = aws_lb_target_group.tg.arn
  target_id        = aws_instance.win.id
  port             = 5000
}

output "alb_dns" {
  value       = aws_lb.alb.dns_name
  description = "Public DNS of the ALB"
}
