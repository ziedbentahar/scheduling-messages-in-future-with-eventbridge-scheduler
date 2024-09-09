resource "aws_iam_role" "run_task_lambda" {

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

resource "aws_iam_policy" "run_task_lambda" {

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
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes",
          "sqs:ChangeMessageVisibility"
        ]
        Resource = aws_sqs_queue.tasks.arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "run_task_lambda" {
  role       = aws_iam_role.run_task_lambda.name
  policy_arn = aws_iam_policy.run_task_lambda.arn
}

data "archive_file" "run_task_lambda" {
  type        = "zip"
  source_dir  = var.run_task_lambda.dist_dir
  output_path = "${path.root}/.terraform/tmp/lambda-zips/${var.run_task_lambda.name}.zip"
}

resource "aws_lambda_function" "run_task_lambda" {
  function_name    = "${var.application}-${var.environment}-${var.run_task_lambda.name}"
  filename         = data.archive_file.run_task_lambda.output_path
  role             = aws_iam_role.run_task_lambda.arn
  handler          = var.run_task_lambda.handler
  source_code_hash = filebase64sha256(data.archive_file.run_task_lambda.output_path)
  runtime          = "provided.al2023"
  memory_size      = "128"
  architectures    = ["arm64"]

  logging_config {
    system_log_level      = "WARN"
    application_log_level = "INFO"
    log_format            = "JSON"
  }
}

resource "aws_cloudwatch_log_group" "run_task_lambda_log_group" {
  name              = "/aws/lambda/${aws_lambda_function.run_task_lambda.function_name}"
  retention_in_days = "3"
}
