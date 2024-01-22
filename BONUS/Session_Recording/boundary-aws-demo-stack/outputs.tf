output "iam_user_names" {
  value = aws_iam_user.user.*.name
}

output "iam_user_arns" {
  value = aws_iam_user.user.*.arn
}

output "iam_access_key_ids" {
  value     = aws_iam_access_key.user_initial_key.*.id
  sensitive = true
}

output "iam_secret_access_keys" {
  value     = aws_iam_access_key.user_initial_key.*.secret
  sensitive = true
}

output "bucket_name" {
  value = aws_s3_bucket.storage_bucket.id
}

output "storage_user_access_key_id" {
  value     = aws_iam_access_key.storage_user_key.id
  sensitive = true
}

output "storage_user_secret_access_key" {
  value     = aws_iam_access_key.storage_user_key.secret
  sensitive = true
}

