output "bastion_public_ip" {
  value = aws_instance.bastion.public_ip
}

output "bastion_public_ipv6" {
  value = aws_instance.bastion.ipv6_addresses[0]
}

output "alb_dns_name" {
  value       = aws_lb.ai_alb.dns_name
  description = "The DNS name of the ALB to access the inference endpoint"
}

output "endpoint_url" {
  value = "http://${aws_lb.ai_alb.dns_name}/v1/completions"
}

output "gpu_private_ip" {
  description = "Private IP of the compute node (CPU/LightGBM by default, GPU/vLLM if var.enable_gpu = true)"
  value       = aws_instance.gpu_node.private_ip
}

output "ssh_command" {
  description = "Run from the terraform directory to SSH to the private compute node through the bastion"
  value       = "ssh -i lab-key -o \"ProxyCommand=ssh -6 -i lab-key -W %h:%p ubuntu@${aws_instance.bastion.ipv6_addresses[0]}\" ubuntu@${aws_instance.gpu_node.private_ip}"
}

output "download_results_command" {
  description = "Run from the terraform directory after the benchmark to download its JSON result"
  value       = "scp -i lab-key -o \"ProxyCommand=ssh -6 -i lab-key -W %h:%p ubuntu@${aws_instance.bastion.ipv6_addresses[0]}\" ubuntu@${aws_instance.gpu_node.private_ip}:/home/ubuntu/ml-benchmark/benchmark_result.json ."
}
