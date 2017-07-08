provider "aws" {
  region  = "us-east-1"
}

# vars
variable "name" {}

variable "batch_job_definition" {}
variable "batch_job_queue" {}
variable "chaqer_lambda_arn" {}
variable "bucket" {}
variable "bucket_arn" {}

variable "is_enabled" {
  default = "true"
}

variable "tags" {
  type = "map"
}

# glue function to submit batch job
data "template_file" "lambda_source" {
  template = <<EOF
'use strict';
const AWS = require('aws-sdk');
const util = require('util');
exports.handler = (event, context, callback) => {

  console.log("Reading input from event:\n", util.inspect(event, {depth: 5}));

  const srcBucket = event.Records[0].s3.bucket.name;
  // Object key may have spaces or unicode non-ASCII characters.
  const srcKey = decodeURIComponent(event.Records[0].s3.object.key.replace(/\+/g, " "));

  console.log('Received event: ', event);
  const params = {
    jobName: '$${name}',
    jobDefinition: '$${batch_job_definition}',
    jobQueue: '$${batch_job_queue}',
    containerOverrides: { environment: [{name: "BUCKET", value: srcBucket}, {name: "FILE",value: srcKey}] },
    parameters: event.parameters || null,
  };
  new AWS.Batch().submitJob(params, (err, data) => {
    if (err) {
      console.error(err);
      const message = 'Error calling SubmitJob for:' + event.jobName;
      console.error(message);
      callback(message);
    } else {
      const jobId = data.jobId;
      console.log('jobId:', jobId);
      callback(null, jobId);
    }
  });
};
EOF

  vars {
    name                 = "${var.name}"
    batch_job_definition = "${var.batch_job_definition}"
    batch_job_queue      = "${var.batch_job_queue}"
  }
}

data "archive_file" "lambda_zip" {
  type                    = "zip"
  source_content          = "${data.template_file.lambda_source.rendered}"
  source_content_filename = "index.js"
  output_path             = "lambda-${var.name}.zip"
}

resource "aws_lambda_alias" "alias" {
  name             = "${var.name}"
  description      = ""
  function_name    = "${aws_lambda_function.func.function_name}"
  function_version = "$LATEST"
}

resource "aws_s3_bucket_notification" "bucket_notification" {
  bucket = "${var.bucket}"

  lambda_function {
    lambda_function_arn = "${var.chaqer_lambda_arn}"
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "videos/"
    filter_suffix       = ".zip"
  }

  lambda_function {
    lambda_function_arn = "${aws_lambda_function.func.arn}"
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "videos/"
    filter_suffix       = ".mp4"
  }
}

resource "aws_iam_role" "role" {
  name = "${var.name}"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_policy" "batch" {
  name        = "${var.name}-batch"
  description = ""

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Action": [
        "batch:DescribeJobs",
        "batch:ListJobs",
        "batch:SubmitJob"
      ],
      "Effect": "Allow",
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "lambda-batch" {
  role       = "${aws_iam_role.role.name}"
  policy_arn = "${aws_iam_policy.batch.arn}"
}

resource "aws_iam_role_policy_attachment" "lambda-cw" {
  role       = "${aws_iam_role.role.name}"
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchLogsFullAccess"
}

resource "aws_iam_role_policy_attachment" "lambda-s3" {
    role       = "${aws_iam_role.role.name}"
    policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

resource "aws_iam_role_policy_attachment" "lambda-attach" {
    role       = "${aws_iam_role.role.name}"
    policy_arn = "arn:aws:iam::aws:policy/AWSLambdaFullAccess"
}

resource "aws_lambda_function" "func" {
  function_name    = "${var.name}"
  filename         = "${data.archive_file.lambda_zip.output_path}"
  source_code_hash = "${data.archive_file.lambda_zip.output_base64sha256}"
  role             = "${aws_iam_role.role.arn}"
  handler          = "index.handler"
  runtime          = "nodejs6.10"
  tags             = "${var.tags}"
}

resource "aws_lambda_permission" "permission" {
  statement_id  = "AllowExecutionFromS3Bucket"
  action        = "lambda:InvokeFunction"
  function_name = "${aws_lambda_function.func.arn}"
  principal     = "s3.amazonaws.com"
  source_arn    = "${var.bucket_arn}"
}


# output

output "aws_lambda_function_arn" {
  value = "${aws_lambda_function.func.arn}"
}
