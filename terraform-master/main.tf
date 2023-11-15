module "ovh" {
    source = "/home/coder/work/Projets_VPN_automation_new/terraform-master/terraform-ovh-infra"
    ansible_ovh_vars_file = "../vars/ansible_ovh_vars_file.yml"
}

module "aws" {
    source = "/home/coder/work/Projets_VPN_automation_new/terraform-master/terraform-aws-infra"
    region = "us-east-1"
    subnet_name_public = "fabalimi-public-subnet_new"
    subnet_name_private = "fabalimi-private-subnet_new"
    igw_name="fabalimi_igw_new"
    route_table_name="fabalimi_route_new"
    private_network_strongswan_adress = "192.168.10.0/24"
    ansible_aws_vars_file = "../vars/ansible_aws_vars_file.yml"
    ansible_nginx_inventory_file="../ansible-nginx-config/inventory.ini"
    customer_gateway_adress = module.ovh.customer_gateway_adress
}
