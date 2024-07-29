provider "aws" {
  region = "us-east-1"
}

resource "aws_lambda_function" "uv_index_alert" {
  filename         = "../lambda_function.zip"
  function_name    = "UVIndexAlert"
  role             = aws_iam_role.lambda_exec.arn
  handler          = "index.handler"
  runtime          = "nodejs14.x"
  source_code_hash = filebase64sha256("../lambda_function.zip")

  environment {
    variables = {
      API_KEY        = var.api_key
      SNS_TOPIC_ARN  = aws_sns_topic.uv_alerts.arn
    }
  }
}

resource "aws_iam_role" "lambda_exec" {
  name = "lambda_exec_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Effect = "Allow",
      Sid    = "",
      Principal = {
        Service = "lambda.amazonaws.com"
      },
    }],
  })
}

resource "aws_iam_role_policy_attachment" "lambda_exec_policy" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_sns_topic" "uv_alerts" {
  name = "UVAlerts"
}

resource "aws_cloudwatch_event_rule" "every_hour" {
  name        = "EveryHour"
  description = "Trigger Lambda every hour"
  schedule_expression = "rate(1 hour)"
}

resource "aws_cloudwatch_event_target" "lambda_target" {
  rule      = aws_cloudwatch_event_rule.every_hour.name
  target_id = "uv_index_alert_lambda"
  arn       = aws_lambda_function.uv_index_alert.arn
}

resource "aws_lambda_permission" "allow_cloudwatch" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.uv_index_alert.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.every_hour.arn
}

resource "aws_api_gateway_rest_api" "uv_index_api" {
  name        = "UVIndexAPI"
  description = "API to trigger UV index check manually"
}

resource "aws_api_gateway_resource" "uv_index_resource" {
  rest_api_id = aws_api_gateway_rest_api.uv_index_api.id
  parent_id   = aws_api_gateway_rest_api.uv_index_api.root_resource_id
  path_part   = "trigger"
}

resource "aws_api_gateway_method" "uv_index_method" {
  rest_api_id   = aws_api_gateway_rest_api.uv_index_api.id
  resource_id   = aws_api_gateway_resource.uv_index_resource.id
  http_method   = "POST"
  authorization = "NONE"

  request_parameters = {
    "method.request.header.x-api-key" = true
  }
}

resource "aws_api_gateway_integration" "lambda_integration" {
  rest_api_id             = aws_api_gateway_rest_api.uv_index_api.id
  resource_id             = aws_api_gateway_resource.uv_index_resource.id
  http_method             = aws_api_gateway_method.uv_index_method.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.uv_index_alert.invoke_arn
}

resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowExecutionFromApiGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.uv_index_alert.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.uv_index_api.execution_arn}/*/*"
}

resource "aws_api_gateway_deployment" "api_deployment" {
  depends_on = [aws_api_gateway_method.uv_index_method]
  rest_api_id = aws_api_gateway_rest_api.uv_index_api.id
  stage_name  = "v1"
}

resource "aws_api_gateway_usage_plan" "usage_plan" {
  name = "UVIndexUsagePlan"

  api_stages {
    api_id = aws_api_gateway_rest_api.uv_index_api.id
    stage  = aws_api_gateway_deployment.api_deployment.stage_name
  }
}

resource "aws_api_gateway_api_key" "api_key" {
  name        = "UVIndexAPIKey"
  description = "API Key for UV Index API"
  enabled     = true
}

resource "aws_api_gateway_usage_plan_key" "usage_plan_key" {
  key_id        = aws_api_gateway_api_key.api_key.id
  key_type      = "API_KEY"
  usage_plan_id = aws_api_gateway_usage_plan.usage_plan.id
}

variable "api_key" {
  description = "API key for the OpenWeatherMap service"
}

output "api_endpoint" {
  value = "${aws_api_gateway_deployment.api_deployment.invoke_url}/trigger"
}

output "api_key" {
  value = aws_api_gateway_api_key.api_key.value
}
