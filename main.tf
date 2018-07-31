provider "aws" {
    region = "us-east-1"
}

resource "aws_iam_role" "lambda_exec_role" {
  name = "lambda_exec_role"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
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
  runtime = "nodejs6.10"
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
  runtime = "nodejs6.10"
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
}

resource "aws_api_gateway_integration" "lambda_read_movies" {
  rest_api_id = "${aws_api_gateway_rest_api.movies.id}"
  resource_id = "${aws_api_gateway_method.get.resource_id}"
  http_method = "${aws_api_gateway_method.get.http_method}"

  integration_http_method = "GET"
  type                    = "AWS_PROXY"
  uri                     = "${aws_lambda_function.read_movies.invoke_arn}"
}

resource "aws_api_gateway_deployment" "deploy_movies" {
  depends_on = [
    "aws_api_gateway_integration.lambda_write_movie",
    "aws_api_gateway_integration.lambda_read_movies",
  ]

  rest_api_id = "${aws_api_gateway_rest_api.movies.id}"
  stage_name  = "staging"
}

output "base_url" {
  value = "${aws_api_gateway_deployment.deploy_movies.invoke_url}"
}
