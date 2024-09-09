resource "aws_sqs_queue" "tasks_dlq" {
  name = "${var.application}-${var.environment}-tasks-dlq"
}


resource "aws_sqs_queue" "tasks" {
  name = "${var.application}-${var.environment}-tasks"
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.tasks_dlq.arn
    maxReceiveCount     = 5 # as an example
  })

}

resource "aws_sqs_queue_redrive_allow_policy" "task_dlq_redrive_policy" {
  queue_url = aws_sqs_queue.tasks_dlq.id

  redrive_allow_policy = jsonencode({
    redrivePermission = "byQueue",
    sourceQueueArns   = [aws_sqs_queue.tasks.arn]
  })
}
