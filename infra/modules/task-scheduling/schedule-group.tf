resource "aws_scheduler_schedule_group" "schedule_group" {
  name = "${var.application}-${var.environment}"
}


resource "aws_iam_role" "scheduler_role" {
  name = "SchedulerRole"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "scheduler.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
  path = "/"
}

resource "aws_iam_policy" "send_message_to_sqs" {
  name        = "send-message-to-sqs"
  description = "Allow Scheduler to send messages to SQS"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["sqs:SendMessage"]
        Resource = aws_sqs_queue.tasks.arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "scheduler_policy_attachment" {
  role       = aws_iam_role.scheduler_role.name
  policy_arn = aws_iam_policy.send_message_to_sqs.arn
}
