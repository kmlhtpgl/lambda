output "base_url" {
  value = "${aws_api_gateway_deployment.key_test.invoke_url}"
}