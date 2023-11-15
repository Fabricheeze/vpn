#Create key pair

#Generer la clé privee RSA_4096� 
resource "tls_private_key" "private_key" {
    algorithm = "RSA"
    rsa_bits = 4096
}

#Create local_file to save the private key
resource "local_file" "private_key_file" {
    content=tls_private_key.private_key.private_key_pem
    filename = "/home/coder/work/Projets_VPN_automation_new/.ssh/fabalimi-ovh-key.pem"
    directory_permission = "0700"
    file_permission = "0700"
}

#Create local_file to save the public key
resource "local_file" "public_key_file" {
    content=tls_private_key.private_key.public_key_openssh
    filename = "/home/coder/work/Projets_VPN_automation_new/.ssh/fabalimi-ovh-key.pub"
    directory_permission = "0700"
    file_permission = "0700"
}

resource "openstack_compute_keypair_v2" "test_keypair" {
  provider   = openstack.ovh
  name       = "openstack-cloud-key-pub"
  public_key = local_file.public_key_file.content
  depends_on = [local_file.public_key_file]
}


# Creating the instance
resource "openstack_compute_instance_v2" "test_terraform_instance" {
  name        = "fabalimi_strongswan_instance_new"        # Instance name
  provider    = openstack.ovh               # Provider name
  image_name  = "Ubuntu 22.04"              # Image name Ubuntu 22.04
  flavor_name = "d2-2"                      # Instance type name
  # Name of openstack_compute_keypair_v2 resource named keypair_test
  key_pair    = openstack_compute_keypair_v2.test_keypair.name
  network {
    name      = "Ext-Net"                   # Adds the network component to reach your instance
  }


  # Exécuter le playbook Ansible après la création de l'instance
  provisioner "local-exec" {
    when    = create
    command = <<-EOT
      echo '[webservers]' > /home/coder/work/Projets_VPN_automation_new/ansible-strongswan-config/inventory.ini
      echo 'strongswan ansible_host=${openstack_compute_instance_v2.test_terraform_instance.network[0].fixed_ip_v4}' >> /home/coder/work/Projets_VPN_automation_new/ansible-strongswan-config/inventory.ini
      echo '' >> /home/coder/work/Projets_VPN_automation_new/ansible-strongswan-config/inventory.ini
      echo '[webservers:vars]' >> /home/coder/work/Projets_VPN_automation_new/ansible-strongswan-config/inventory.ini
      echo 'ansible_ssh_private_key_file=${local_file.private_key_file.filename}' >> /home/coder/work/Projets_VPN_automation_new/ansible-strongswan-config/inventory.ini
      echo 'ansible_user=ubuntu' >> /home/coder/work/Projets_VPN_automation_new/ansible-strongswan-config/inventory.ini
      
      # Boucle d'attente active
      RETRIES=30
      DELAY=60
      COUNT=0
      echo "Attente pour l'instance OVH de devenir accessible via SSH..."
      until ssh -o "StrictHostKeyChecking=no" -i ${local_file.private_key_file.filename} ubuntu@${openstack_compute_instance_v2.test_terraform_instance.network[0].fixed_ip_v4} "echo Instance is up" || [ $COUNT -eq $RETRIES ]; do
        sleep $DELAY
        COUNT=$((COUNT+1))
      done

      if [ $COUNT -eq $RETRIES ]; then
        echo "Timeout atteint en attendant l'instance OVH."
        exit 1
      fi
            
      ansible-playbook -i /home/coder/work/Projets_VPN_automation_new/ansible-strongswan-config/inventory.ini /home/coder/work/Projets_VPN_automation_new/ansible-strongswan-config/tasks/execution_playbooks_config.yml
    EOT
  }
}

#Display Public IP Address allocated to instance
output "test_terraform_instance_ip" {
  value = openstack_compute_instance_v2.test_terraform_instance.network[0].fixed_ip_v4
}

resource "local_file" "ansible_vars" {
  content = <<-DOC
    # Ansible vars_file containing variable values from Terraform.
    # Generated by Terraform mgmt configuration.

    # OVH Specific Variables
    ovh_instance_ip: ${openstack_compute_instance_v2.test_terraform_instance.network[0].fixed_ip_v4}
    ovh_instance_user: "ubuntu"

    # VPN Configuration
    vpn_local_cidr: ${openstack_compute_instance_v2.test_terraform_instance.network[0].fixed_ip_v4}

    main_interface: "ens3"

    DOC
  filename = var.ansible_ovh_vars_file
}

#Create inventory.ini
#resource "local_file" "inventory_file" {
# content = <<-DOC
#    [webservers]
#    strongswan ansible_host=${openstack_compute_instance_v2.test_terraform_instance.network[0].fixed_ip_v4}

#    [webservers:vars]
#    ansible_ssh_private_key_file=${local_file.private_key_file.filename}
#    ansible_user=ubuntu
#  DOC
#  filename = "/home/coder/work/Projets_VPN_automation_new/ansible-strongswan-config/inventory.ini"
#}
