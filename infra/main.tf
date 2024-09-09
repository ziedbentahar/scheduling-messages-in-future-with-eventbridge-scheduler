module "task_scheduling" {
  source      = "./modules/task-scheduling"
  application = var.application
  environment = var.environment

  run_task_lambda = {
    dist_dir = "../src/target/lambda/run-task"
    name     = "run-task"
    handler  = "bootstrap"
  }

  schedule_task_lambda = {
    dist_dir = "../src/target/lambda/schedule-task"
    name     = "schedule-task"
    handler  = "bootstrap"
  }
}
