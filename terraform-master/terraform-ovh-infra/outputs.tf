output "customer_gateway_adress" {
  value = openstack_compute_instance_v2.test_terraform_instance.access_ip_v4
  description = "L'adresse IP publique de l'instance OpenStack"
}
