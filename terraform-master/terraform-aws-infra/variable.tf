variable "region" {
  type = string
}
variable "subnet_name_public" {
  type = string
}
variable "subnet_name_private" {
  type = string
}
variable "igw_name" {
  type = string
}
variable "route_table_name" {
  type = string
}
variable "private_network_strongswan_adress" {
  type = string
}
variable "customer_gateway_adress" {
  type = string
}
variable "ansible_aws_vars_file" {
  type = string
}
variable "ansible_nginx_inventory_file" {
  type = string
}