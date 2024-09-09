variable "schedule_task_lambda" {
  type = object({
    dist_dir = string
    name     = string
    handler  = string
  })
}

variable "run_task_lambda" {
  type = object({
    dist_dir = string
    name     = string
    handler  = string
  })
}

variable "application" {
  type = string
}

variable "environment" {
  type = string
}


