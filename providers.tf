#option 1: you can configure access key ID and secret access key 
#provider "aws" {
#    region = " "
#    shared_credentials_file = " "
#    profile = " "
#}

#option 2: you can specify a session access token, typically provided after a successful identity federation or Multi-Factor Authentication (MFA) login.
#provider "aws" {
#  region = " "
#  token  = "my-token"
#}

#option 3: Environment Variables In the command shell, the environment variables are set as follows:
# export AWS_ACCESS_KEY_ID="my-access-key"
# export AWS_SECRET_ACCESS_KEY="my-secret-key"
# export AWS_REGION="us-west-2"
# Alternatively, a token can be used instead of Key ID and Access Key:export AWS_SESSION_TOKEN="my-token"
#provider "aws" {
#       region = "${var.region}"
#}

provider "aws" {}