resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
  lower   = true
  numeric = true
}

resource "aws_s3_bucket" "origin_bucket" {
  bucket = "${var.identifier}-image-bucket-origin-${random_string.suffix.result}"
  tags = {
    Environment = "${var.identifier}"
  }
}

resource "aws_s3_bucket" "transform_bucket" {
  bucket = "${var.identifier}-image-bucket-transform-${random_string.suffix.result}"
  tags = {
    Environment = "${var.identifier}"
  }
}

resource "aws_s3_bucket_notification" "origin_bucket_notification" {
  bucket = aws_s3_bucket.origin_bucket.id
  eventbridge = true
}

data "archive_file" "invoke_lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../lambda_functions_scripts/s3_trigger"
  output_path = "${path.module}/../lambda_functions_scripts/s3_trigger.zip"
}

resource "aws_iam_role" "lambda_role" {
  name = "${var.identifier}-lambda-execution-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "lambda.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_policy" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_lambda_function" "s3_trigger_lambda" {
  function_name = "${var.identifier}-s3-trigger-lambda"
  handler       = "s3_trigger.lambda_handler"
  runtime       = "python3.12"
  role          = aws_iam_role.lambda_role.arn
  filename      = data.archive_file.invoke_lambda_zip.output_path

  source_code_hash = filebase64sha256(data.archive_file.invoke_lambda_zip.output_path)
}

resource "aws_cloudwatch_event_rule" "s3_trigger_cloudwatch_event_rule" {
  name        = "${var.identifier}-s3-object-created-rule"
  description = "EventBridge rule for S3 object created events"
  event_pattern = jsonencode({
    "source": ["aws.s3"],
    "detail-type": ["Object Created"],
    "detail": {
      "bucket": {
        "name": ["${var.identifier}-image-bucket-origin-${random_string.suffix.result}"]
      }
    }
  })
}

resource "aws_cloudwatch_event_target" "aws_cloudwatch_event_target" {
  rule      = aws_cloudwatch_event_rule.s3_trigger_cloudwatch_event_rule.name
  target_id = "lambda-target"
  arn       = aws_lambda_function.s3_trigger_lambda.arn
}

resource "aws_lambda_permission" "lambda_eventbridge_permissions" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.s3_trigger_lambda.arn
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.s3_trigger_cloudwatch_event_rule.arn
}