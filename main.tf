provider "aws" {
    region = "us-east-1"
}

resource "aws_iam_role" "lambda_exec_role" {
  name = "lambda_exec_role"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [{
    "Action": "sts:AssumeRole",
    "Principal": {
      "Service": ["lambda.amazonaws.com", "apigateway.amazonaws.com"]
    },
    "Effect": "Allow",
    "Sid": ""
  }]
}
EOF
}

resource "aws_iam_role_policy_attachment" "sto-readonly-role-policy-attach" {
  role = "${aws_iam_role.lambda_exec_role.name}"
  policy_arn = "arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess"
}

resource "aws_dynamodb_table" "movies-dynamodb-table" {
  name           = "movies"
  read_capacity  = 5
  write_capacity = 5
  hash_key       = "id"
  range_key      = "name"

  attribute {
    name = "id"
    type = "S"
  }

  attribute {
    name = "name"
    type = "S"
  }
}

resource "aws_lambda_function" "write_movie" {
  function_name = "CreateMovie"
  handler = "index.handler"
  runtime = "nodejs8.10"
  filename = "create_movie.zip"
  source_code_hash = "${base64sha256(file("create_movie.zip"))}"
  role = "${aws_iam_role.lambda_exec_role.arn}"

  environment {
    variables = {
      TABLE_NAME = "movies"
    }
  }
}

resource "aws_lambda_function" "read_movies" {
  function_name = "ReadMovies"
  handler = "index.handler"
  runtime = "nodejs8.10"
  filename = "read_movies.zip"
  source_code_hash = "${base64sha256(file("read_movies.zip"))}"
  role = "${aws_iam_role.lambda_exec_role.arn}"

  environment {
    variables = {
      TABLE_NAME = "movies"
    }
  }
}

resource "aws_lambda_permission" "apigw_perm_post" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = "${aws_lambda_function.write_movie.arn}"
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_api_gateway_deployment.deploy_movies.execution_arn}/*/*"
}

resource "aws_lambda_permission" "apigw_perm_get" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = "${aws_lambda_function.read_movies.arn}"
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_api_gateway_deployment.deploy_movies.execution_arn}/*/*"
}

resource "aws_api_gateway_rest_api" "movies" {
  name        = "Movies"
  description = "Serverless app example for movies"
}

resource "aws_iam_policy" "allow_invoke_lambda" {
    name        = "invokeLambda_TF"
    description = "Permits Invoking Lambda - deployed by Terraform"
    path        = "/service-role/"
    policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "lambda:InvokeFunction",
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_iam_policy_attachment" "attach_lambdaInvoking" {
    name        = "invokingLambdaAttachment_TF"
    roles       = ["${aws_iam_role.lambda_exec_role.name}"]
    policy_arn  = "${aws_iam_policy.allow_invoke_lambda.arn}"
}

resource "aws_api_gateway_method" "get" {
  rest_api_id   = "${aws_api_gateway_rest_api.movies.id}"
  resource_id   = "${aws_api_gateway_rest_api.movies.root_resource_id}"
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_method" "post" {
  rest_api_id   = "${aws_api_gateway_rest_api.movies.id}"
  resource_id   = "${aws_api_gateway_rest_api.movies.root_resource_id}"
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "lambda_write_movie" {
  rest_api_id = "${aws_api_gateway_rest_api.movies.id}"
  resource_id = "${aws_api_gateway_method.post.resource_id}"
  http_method = "${aws_api_gateway_method.post.http_method}"

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = "${aws_lambda_function.write_movie.invoke_arn}"
  credentials             = "${aws_iam_role.lambda_exec_role.arn}"
}

resource "aws_api_gateway_method_response" "post_response" {
  rest_api_id = "${aws_api_gateway_rest_api.movies.id}"
  resource_id = "${aws_api_gateway_method.post.resource_id}"
  http_method = "${aws_api_gateway_method.post.http_method}"
  status_code = "200"

  response_models = {
    "application/json" = "Empty"
  }
}

resource "aws_api_gateway_integration_response" "lambda_write_movie" {
  depends_on = ["aws_api_gateway_integration.lambda_write_movie"]
  rest_api_id = "${aws_api_gateway_rest_api.movies.id}"
  resource_id = "${aws_api_gateway_method.post.resource_id}"
  http_method = "${aws_api_gateway_method.post.http_method}"
  status_code = "${aws_api_gateway_method_response.post_response}"
  status_code = "${aws_api_gateway_method_response.post_response.status_code}"

  response_templates = {
    "application/json" = ""
  }
}

resource "aws_api_gateway_integration" "lambda_read_movies" {
  rest_api_id = "${aws_api_gateway_rest_api.movies.id}"
  resource_id = "${aws_api_gateway_method.get.resource_id}"
  http_method = "${aws_api_gateway_method.get.http_method}"

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = "${aws_lambda_function.read_movies.invoke_arn}"
  credentials             = "${aws_iam_role.lambda_exec_role.arn}"
}

resource "aws_api_gateway_method_response" "get_response" {
  rest_api_id = "${aws_api_gateway_rest_api.movies.id}"
  resource_id = "${aws_api_gateway_method.get.resource_id}"
  http_method = "${aws_api_gateway_method.get.http_method}"
  status_code = "200"

  response_models = {
    "application/json" = "Empty"
  }
}

resource "aws_api_gateway_integration_response" "lambda_read_movies" {
  depends_on = ["aws_api_gateway_integration.lambda_read_movies"]
  rest_api_id = "${aws_api_gateway_rest_api.movies.id}"
  resource_id = "${aws_api_gateway_method.get.resource_id}"
  http_method = "${aws_api_gateway_method.get.http_method}"
  status_code = "${aws_api_gateway_method_response.get_response}"
  status_code = "${aws_api_gateway_method_response.get_response.status_code}"

  response_templates = {
    "application/json" = ""
  }
}

resource "aws_api_gateway_deployment" "deploy_movies" {
  depends_on = [
    "aws_api_gateway_integration_response.lambda_write_movie",
    "aws_api_gateway_integration_response.lambda_read_movies",
  ]

  rest_api_id = "${aws_api_gateway_rest_api.movies.id}"
  stage_name  = "staging"
}

output "base_url" {
  value = "${aws_api_gateway_deployment.deploy_movies.invoke_url}"
}
