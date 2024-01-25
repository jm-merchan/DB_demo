output "worker_fqdn" {
  value = aws_instance.worker.public_dns
}