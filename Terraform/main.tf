resource "aws_s3_bucket" "uploads_bucket" {
  bucket = "demo-content-uploads-12345"
  acl    = "private"
}

resource "aws_lambda_function" "content_processor" {
  function_name = "contentProcessor"
  handler       = "handler.lambda_handler"
  runtime       = "python3.8"
  role          = aws_iam_role.lambda_exec_role.arn
  filename      = "${path.module}/lambda_function.zip"  

  source_code_hash = filebase64sha256("${path.module}/lambda_function.zip")
  environment {
    variables = {
      BUCKET_NAME = aws_s3_bucket.uploads_bucket.bucket
      
    }
  }
}

resource "aws_iam_role" "lambda_exec_role" {
  name = "lambda_exec_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action    = "sts:AssumeRole",
      Effect    = "Allow",
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
  }

# IAM-Rolle erstellen
resource "aws_iam_role" "ecsTaskExecutionRole" {
  name = "ecsTaskExecutionRole"
  assume_role_policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [{
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ecs-tasks.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }]
  })
}

# Die benötigte Policy anhängen
resource "aws_iam_role_policy_attachment" "ecsTaskExecutionRolePolicy" {
  role       = aws_iam_role.ecsTaskExecutionRole.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy" "lambda_policy" {
  name   = "lambda_policy"
  role   = aws_iam_role.lambda_exec_role.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect   = "Allow",
        Action   = [
          "s3:GetObject",
          "s3:PutObject"
        ],
        Resource = "${aws_s3_bucket.uploads_bucket.arn}/*"
      }
    ]
  })
}

resource "aws_ecs_cluster" "demo_cluster" {
  name = "demo-ecs-cluster"
}

resource "aws_ecs_task_definition" "ki_task" {
  family                   = "ki-service-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"

  execution_role_arn       = aws_iam_role.ecsTaskExecutionRole.arn
  container_definitions = jsonencode([
    {
      name      = "ki-service"
      image     = "public.ecr.aws/h5d1a7s0/ki-service:latest" 
      essential = true
      portMappings = [
        {
          containerPort = 5000,
          hostPort      = 5000,
          protocol      = "tcp"
        }
      ]
      environment = [
        {
          name  = "ENV_VAR",
          value = "value"
        }
      ]
    }
  ])
}

resource "aws_ecs_service" "ki_service" {
  name            = "ki-service"
  cluster         = aws_ecs_cluster.demo_cluster.id
  task_definition = aws_ecs_task_definition.ki_task.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets         = ["subnet-09fbf13b264b08404"] 
    assign_public_ip = true
  }
}

resource "aws_cloudwatch_dashboard" "demo_dashboard" {
  dashboard_name = "demo-dashboard"
  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          metrics = [
            [ "AWS/EC2", "CPUUtilization", "InstanceId", "i-0123456789abcdef0", { "region": "us-east-1" } ]
          ]
          view        = "timeSeries"
          region      = "us-east-1"       
          title       = "EC2 CPU Utilization"
          annotations = {}                   
        }
      }
    ]
  })
}