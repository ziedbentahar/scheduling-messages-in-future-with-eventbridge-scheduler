resource "aws_lambda_event_source_mapping" "schedule_task_lambda" {
  event_source_arn        = aws_dynamodb_table.table.stream_arn
  function_name           = aws_lambda_function.schedule_task_lambda.function_name
  starting_position       = "TRIM_HORIZON"
  function_response_types = ["ReportBatchItemFailures"]

  filter_criteria {
    filter {
      pattern = jsonencode({
        eventName = ["INSERT"]
      })
    }
  }
}


resource "aws_iam_role" "schedule_task_lambda" {

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  path = "/"
}

resource "aws_iam_policy" "schedule_task_lambda" {

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "scheduler:CreateSchedule"
        ]
        Resource = "arn:aws:scheduler:*:*:schedule/${aws_scheduler_schedule_group.schedule_group.name}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "iam:PassRole"
        ]
        Resource = aws_iam_role.scheduler_role.arn
      },
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetRecords",
          "dynamodb:GetShardIterator",
          "dynamodb:DescribeStream",
          "dynamodb:ListStreams"
        ]
        Resource = ["${aws_dynamodb_table.table.arn}/stream/*"]
      },
      {
        Effect = "Allow"
        Action = [
          "lambda:InvokeFunction"
        ]
        Resource = ["${aws_dynamodb_table.table.arn}/stream/*"]
      }
    ]
  })
}


resource "aws_iam_role_policy_attachment" "schedule_task_lambda" {
  role       = aws_iam_role.schedule_task_lambda.name
  policy_arn = aws_iam_policy.schedule_task_lambda.arn
}

data "archive_file" "schedule_task_lambda" {
  type        = "zip"
  source_dir  = var.schedule_task_lambda.dist_dir
  output_path = "${path.root}/.terraform/tmp/lambda-zips/${var.schedule_task_lambda.name}.zip"
}

resource "aws_lambda_function" "schedule_task_lambda" {
  function_name    = "${var.application}-${var.environment}-${var.schedule_task_lambda.name}"
  filename         = data.archive_file.schedule_task_lambda.output_path
  role             = aws_iam_role.schedule_task_lambda.arn
  handler          = var.schedule_task_lambda.handler
  source_code_hash = filebase64sha256(data.archive_file.schedule_task_lambda.output_path)
  runtime          = "provided.al2023"
  memory_size      = "128"
  architectures    = ["arm64"]
  
  environment {
    variables = {
      SCHEDULER_GROUP_NAME = aws_scheduler_schedule_group.schedule_group.name
      SCHEDULER_ROLE_ARN = aws_iam_role.scheduler_role.arn
      SCHEDULER_TARGET_ARN = aws_sqs_queue.tasks.arn
    }
  }

  logging_config {
    system_log_level      = "WARN"
    application_log_level = "INFO"
    log_format            = "JSON"
  }
}

resource "aws_cloudwatch_log_group" "schedule_task_lambda_log_group" {
  name              = "/aws/lambda/${aws_lambda_function.schedule_task_lambda.function_name}"
  retention_in_days = "3"
}
