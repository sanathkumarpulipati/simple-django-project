variable "aws_region" {
  type        = string
  description = "AWS region"
  default     = "ap-south-1"
}

variable "key_name" {
  type        = string
  description = "Existing EC2 key pair name for Windows (used to decrypt password)"
  default     = "windows-key"
}

variable "repo_url" {
  type        = string
  description = "GitHub repo URL (https or ssh). If private over https, embed token as described below."
  default     = "https://github.com/sanathkumarpulipati/simple-django-project.git"
}

variable "branch" {
  type        = string
  description = "Git branch to checkout"
  default     = "master"
}

variable "app_dir" {
  type        = string
  description = "Directory to clone into on Windows"
  default     = "C:\\app"
}

variable "app_start_cmd" {
  type        = string
  description = "Command to start your app (must bind 0.0.0.0:5000). Example: python app.py"
  default     = "python app.py" 
}

variable "allowed_rdp_cidr" {
  type        = string
  description = "CIDR allowed to RDP (3389) into instance"
  default     = "0.0.0.0/0" 
}
