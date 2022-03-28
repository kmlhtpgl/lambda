resource "aws_api_gateway_rest_api" "key_test" {
  name        = "Serverlesskey_test"
  description = "Terraform Serverless Application key_test"
  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

