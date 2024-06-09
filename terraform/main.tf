data "aws_caller_identity" "current" {}

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
  environment {
    variables = {
      ORIGIN_BUCKET_NAME = aws_s3_bucket.origin_bucket.bucket,
      TRANSFORM_BUCKET_NAME  = aws_s3_bucket.transform_bucket.bucket,
      DATASYNC_ORIGIN_S3_LOCATION = aws_datasync_location_s3.datasync_s3_origin_location.arn
      DATASYNC_TRANSFORM_S3_LOCATION = aws_datasync_location_s3.datasync_s3_transform_location.arn
      DATASYNC_EFS_LOCATION = aws_datasync_location_efs.datasync_efs_location.arn
      BATCH_JOB_QUEUE_NAME = aws_batch_job_queue.batch_job_queue.arn

    }
  }
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

resource "aws_efs_file_system" "efs_file_system" {
  creation_token = "${var.identifier}-efs"
  tags = {
    Environment = "${var.identifier}"
    Name = "${var.identifier}-efs"
  }
}

resource "aws_efs_mount_target" "efs_mount_target" {
  for_each = { for idx, subnet_id in var.subnet_ids : idx => subnet_id }
  file_system_id  = aws_efs_file_system.efs_file_system.id
  subnet_id       = each.value
  security_groups = [aws_security_group.efs_security_group.id]
}

resource "aws_security_group" "efs_security_group" {
  name   = "allow_efs"
  vpc_id = var.vpc_id

  ingress {
    from_port   = 2049
    to_port     = 2049
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Environment = "${var.identifier}"
  }
}

resource "aws_iam_role" "datasync_s3_role" {
  name = "${var.identifier}-datasync-s3-role"

  assume_role_policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
      {
        "Action": "sts:AssumeRole",
        "Principal": {
          "Service": "datasync.amazonaws.com"
        },
        "Effect": "Allow",
        "Sid": ""
      }
    ]
  })

  inline_policy {
    name   = "${var.identifier}-s3-access-datasync-policy"
    policy = jsonencode({
      "Version": "2012-10-17",
      "Statement": [
        {
          "Effect": "Allow",
          "Action": [
            "s3:ListBucket",
            "s3:GetObject",
            "s3:GetObjectVersion",
            "s3:GetBucketLocation"
          ],
          "Resource": [
            aws_s3_bucket.origin_bucket.arn,
            aws_s3_bucket.transform_bucket.arn,
            "${aws_s3_bucket.origin_bucket.arn}/*",
            "${aws_s3_bucket.transform_bucket.arn}/*"
          ]
        }
      ]
    })
  }
  tags = {
    Environment = "${var.identifier}"
  }
}

resource "aws_datasync_location_s3" "datasync_s3_origin_location" {
  s3_bucket_arn = aws_s3_bucket.origin_bucket.arn
  subdirectory  = "/"  # Optional: If you want to specify a subdirectory within the S3 bucket
  s3_config {
    bucket_access_role_arn = aws_iam_role.datasync_s3_role.arn
  }
  tags = {
    Environment = "${var.identifier}"
  }
}

resource "aws_datasync_location_s3" "datasync_s3_transform_location" {
  s3_bucket_arn = aws_s3_bucket.transform_bucket.arn
  subdirectory  = "/"  # Optional: If you want to specify a subdirectory within the S3 bucket
  s3_config {
    bucket_access_role_arn = aws_iam_role.datasync_s3_role.arn
  }
  tags = {
    Environment = "${var.identifier}"
  }
}

resource "aws_datasync_location_efs" "datasync_efs_location" {
  ec2_config {
    security_group_arns = [aws_security_group.efs_security_group.arn]
    subnet_arn          = "arn:aws:ec2:${var.aws_region}:${data.aws_caller_identity.current.account_id}:subnet/${var.subnet_ids[0]}"
  }
  efs_file_system_arn = aws_efs_file_system.efs_file_system.arn
  subdirectory        = "/"  # Optional: If you want to specify a subdirectory within the EFS file system
  depends_on = [
    aws_efs_file_system.efs_file_system,
    aws_efs_mount_target.efs_mount_target
  ]
  tags = {
    Environment = "${var.identifier}"
  }
}

resource "aws_batch_compute_environment" "batch_environment" {
  compute_environment_name = "${var.identifier}-compute-environment"
  type                     = "MANAGED"
  state                    = "ENABLED"
  compute_resources {
    type          = "EC2"
    instance_role = aws_iam_instance_profile.batch_instance_profile.arn
    instance_type = ["optimal"]
    min_vcpus     = 0
    max_vcpus     = 2
    subnets       = var.subnet_ids
    security_group_ids = [aws_security_group.batch_security_group.id] # Replace with your security group ID(s)
  }
}

resource "aws_iam_instance_profile" "batch_instance_profile" {
  name = "${var.identifier}-batch-instance-profile"
  role = aws_iam_role.batch_instance_role.name
}

resource "aws_iam_role" "batch_instance_role" {
  name               = "${var.identifier}-batch-instance-role"
  assume_role_policy = jsonencode({
    Version   = "2012-10-17",
    Statement = [{
      Effect    = "Allow",
      Principal = {
        Service = "ec2.amazonaws.com"
      },
      Action    = "sts:AssumeRole"
    }]
  })

  inline_policy {
    name   = "${var.identifier}-batch-instance-policy"
    policy = jsonencode({
      Version   = "2012-10-17",
      Statement = [{
        Effect    = "Allow",
        Action    = "batch:*",
        Resource  = "*"
      }]
    })
  }
}

resource "aws_security_group" "batch_security_group" {
  name        = "${var.identifier}-batch-security-group"
  description = "Security group for AWS Batch compute environment"
  vpc_id      = var.vpc_id

  // Allow outbound traffic to the internet
  egress {
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_batch_job_definition" "batch_job_definition" {
  name        = "${var.identifier}-batch-job-definition"
  type        = "container"
  parameters = {
    "param1" = "value1"
    "param2" = "value2"
  }

  container_properties = jsonencode({
    image       = "busybox"
    vcpus       = 1
    memory      = 1024
    command     = ["echo", "hello", "world"]
    environment = [
      {name = "ENV_VAR_1", value = "value1"},
      {name = "ENV_VAR_2", value = "value2"},
    ]
    volumes = [
      {
        name = "efs-volume"   # Name of the EFS volume
        efs_volume_configuration = {
          file_system_id = aws_efs_file_system.efs_file_system.id   # ID of your EFS file system
        }
      }
    ]
    mount_points = [
      {
        source_volume = "efs-volume"     # Name of the volume defined above
        container_path = "/mnt/efs"       # Container mount path
        read_only = false
      }
    ]
  })

  retry_strategy {
    attempts = 1
  }

  timeout {
    attempt_duration_seconds = 3600
  }

  depends_on = [aws_batch_compute_environment.batch_environment]
}

resource "aws_batch_job_queue" "batch_job_queue" {
  name          = "${var.identifier}-batch-job-queue"
  state         = "ENABLED"
  priority      = 1
  compute_environment_order {
    order               = 1
    compute_environment = aws_batch_compute_environment.batch_environment.arn
  }
}