
# Resource: https://cloud.google.com/community/tutorials/modular-load-balancing-with-terraform
variable "region1" {
  default = "us-west1"
}
variable "region2" {
  default = "us-central1"
}
variable "region1_zone1" {
  default = "us-west1-a"
}
variable "region1_zone2" {
  default = "us-west1-b"
}
variable "region1_zone3" {
  default = "us-west1-c"
}
variable "region2_zone1" {
  default = "us-central1-a"
}
variable "region2_zone2" {
  default = "us-central1-b"
}
variable "region2_zone3" {
  default = "us-central1-f"
}
variable "project_name" {
  default = "next19-audit-logs"
  description = "The ID of the Google Cloud project"
}

/*
# Associate the service account created using the console: IAM & Admin -> Service Accounts
variable "credentials_file_path" {
  description = "Path to the JSON file used to describe your account credentials"
  default     = "~/tfkey.json"     # Put the .json key file in your home directory or specify the path if you created subdirs
}
*/