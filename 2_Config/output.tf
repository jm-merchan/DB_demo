output "worker_fqdn" {
  value = aws_instance.worker.public_dns
}

output "target_readonly" {
  value = boundary_target.read_only.id
}

output "target_readwrite" {
  value = boundary_target.write.id
}

output "target_dba" {
  value = boundary_target.dba.id
}