terraform {
  required_version = ">= 0.13.0"
  required_providers {

    aws = ">= 2.7.0"

  }

}

provider "aws" {
  region = "us-east-1"
}

terraform {
  backend "s3" {
    # Replace this with your bucket name!
    bucket = "key-test-kml2"
    key    = "global/s3/terraform.tfstate"
    region = "us-east-1"

  }
}
/*
resource "aws_ssm_parameter" "key_test" {
  name  = "key_test"
  type  = "String"
  value = "${var.key_test}"
}
*/

data "archive_file" "source" {
  type        = "zip"
  source_dir  = "./function/"
  output_path = "./key_test2.zip"
}

resource "aws_s3_bucket" "bucket" {
  bucket = "my-tf-test-bucket-kml"

  tags = {
    Name        = "My bucket"
    Environment = "Test"
  }
}

resource "aws_s3_bucket_object" "file_upload" {
  bucket = "${aws_s3_bucket.bucket.id}"
  key    = "lambda-functions/key_test2.zip"
  source = "${data.archive_file.source.output_path}" # its mean it depended on zip
}


resource "aws_lambda_function" "key_test" {
  function_name = "key_test"

  # The bucket name as created earlier with "aws s3api create-bucket"
  s3_bucket = "${aws_s3_bucket.bucket.bucket}"
  s3_key      = "${aws_s3_bucket_object.file_upload.key}" # its mean its depended on upload key
  #s3_key    = "v1.0.0/key_test.zip"
  source_code_hash = "${base64sha256(data.archive_file.source.output_path)}"

  # "key_test" is the filename within the zip file (key_test.py) and "handler"
  # is the name of the property under which the handler function was
  # exported in that file.
  handler = "key_test.lambda_handler" #function/key_test.lambda_handler
  runtime = "python3.9"

  role = "${aws_iam_role.lambda_exec.arn}"
}

# IAM role which dictates what other AWS services the Lambda function
# may access.
resource "aws_iam_role" "lambda_exec" {
  name = "serverless_key_test_lambda"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      },
    ]
  })
}

resource "aws_iam_policy" "policy" {
  name        = "test_policy1"
  path        = "/"
  description = "My test policy"

  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  policy = <<EOT
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": "logs:CreateLogGroup",
            "Resource": "arn:aws:lambda:us-east-1:122072647213:*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "logs:CreateLogStream",
                "logs:PutLogEvents"
            ],
            "Resource": [
                "arn:aws:logs:us-east-1:122072647213:log_group:aws/lambda/key_test:*"
            ]
        }
    ]
}
EOT
}

resource "aws_iam_policy" "policy2" {
  name        = "test_policy2"
  path        = "/"
  description = "My test policy"

  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  policy = <<EOT
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "ssm:PutParameter",
                "ssm:DeleteParameter",
                "ssm:GetParameterHistory",
                "ssm:GetParametersByPath",
                "ssm:GetParameters",
                "ssm:GetParameter",
                "ssm:DeleteParameters"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": "ssm:DescribeParameters",
            "Resource": "*"
        }
    ]
}
EOT
}

resource "aws_iam_role_policy_attachment" "test-attach" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = aws_iam_policy.policy.arn
}

resource "aws_iam_role_policy_attachment" "test-attach2" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = aws_iam_policy.policy2.arn
}

resource "aws_api_gateway_resource" "key_test" {
  rest_api_id = "${aws_api_gateway_rest_api.key_test.id}"
  parent_id   = "${aws_api_gateway_rest_api.key_test.root_resource_id}"
  path_part   = "key_test"
}

resource "aws_api_gateway_method" "key_test" {
  rest_api_id   = "${aws_api_gateway_rest_api.key_test.id}"
  resource_id   = "${aws_api_gateway_resource.key_test.id}"
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_method_response" "response_200" {
  rest_api_id = aws_api_gateway_rest_api.key_test.id
  resource_id = aws_api_gateway_resource.key_test.id
  http_method = aws_api_gateway_method.key_test.http_method
  status_code = "200"
  
}


resource "aws_api_gateway_integration" "lambda" {
  rest_api_id = "${aws_api_gateway_rest_api.key_test.id}"
  resource_id = "${aws_api_gateway_method.key_test.resource_id}"
  http_method = "${aws_api_gateway_method.key_test.http_method}"

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = "${aws_lambda_function.key_test.invoke_arn}"
}

resource "aws_api_gateway_integration_response" "key_test" {
  rest_api_id = aws_api_gateway_rest_api.key_test.id
  resource_id = aws_api_gateway_resource.key_test.id
  http_method = aws_api_gateway_method.key_test.http_method
  status_code = aws_api_gateway_method_response.response_200.status_code

  depends_on = [
    aws_api_gateway_integration.lambda
  ]
}
/*
resource "aws_api_gateway_method" "proxy_root" {
  rest_api_id   = "${aws_api_gateway_rest_api.key_test.id}"
  resource_id   = "${aws_api_gateway_rest_api.key_test.root_resource_id}"
  http_method   = "ANY"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "lambda_root" {
  rest_api_id = "${aws_api_gateway_rest_api.key_test.id}"
  resource_id = "${aws_api_gateway_method.key_test.resource_id}"
  http_method = "${aws_api_gateway_method.key_test.http_method}"

  integration_http_method = "GET"
  type                    = "AWS_PROXY"
  uri                     = "${aws_lambda_function.key_test.invoke_arn}"
}
*/
resource "aws_api_gateway_deployment" "key_test" {
  depends_on = [
    "aws_api_gateway_integration.lambda",
   ]

  rest_api_id = "${aws_api_gateway_rest_api.key_test.id}"
  stage_name  = "test"
}

resource "aws_lambda_permission" "apigw" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = "${aws_lambda_function.key_test.function_name}"
  principal     = "apigateway.amazonaws.com"

  # The /*/* portion grants access from any method on any resource
  # within the API Gateway "REST API".
  source_arn = "${aws_api_gateway_rest_api.key_test.execution_arn}/*/GET/key_test"
}