resource "random_string" "random" {
  length           = 16
  special          = true
}

resource "scaleway_instance_ip" "master_0" {}

resource "scaleway_instance_ip" "master_1" {}

resource "scaleway_instance_ip" "master_2" {}

resource "scaleway_instance_server" "master_0" {
  name  = "master_0"
  type  = "DEV1-S"
  image = "ubuntu_focal"
  ip_id = scaleway_instance_ip.master_0.id
  provisioner "remote-exec" {
    inline = [
      "export K3S_TOKEN='${random_string.random.result}'",
      "curl -sfL https://get.k3s.io | sh -s - server --cluster-init",
    ]
    connection {
      host = scaleway_instance_ip.master_0.address
      type     = "ssh"
      user     = "root"
      agent       = true
    }
  }
}

resource "scaleway_instance_server" "master_1" {
  name  = "master_1"
  type  = "DEV1-S"
  image = "ubuntu_focal"
  ip_id = scaleway_instance_ip.master_1.id
  provisioner "remote-exec" {
    inline = [
      "export K3S_TOKEN='${random_string.random.result}'",
      "curl -sfL https://get.k3s.io | sh -s - server --server https://${scaleway_instance_server.master_0.public_ip}:6443",
    ]
    connection {
      host = scaleway_instance_ip.master_1.address
      type     = "ssh"
      user     = "root"
      agent       = true
    }
  }
  depends_on = [scaleway_instance_server.master_0]
}

resource "scaleway_instance_server" "master_2" {
  name  = "master_2"
  type  = "DEV1-S"
  image = "ubuntu_focal"
  ip_id = scaleway_instance_ip.master_2.id
  provisioner "remote-exec" {
    inline = [
      "export K3S_TOKEN='${random_string.random.result}'",
      "curl -sfL https://get.k3s.io | sh -s - server --server https://${scaleway_instance_server.master_0.public_ip}:6443",
    ]
    connection {
      host = scaleway_instance_ip.master_2.address
      type     = "ssh"
      user     = "root"
      agent       = true
    }
  }
  depends_on = [scaleway_instance_server.master_0]
}

resource "scaleway_instance_ip" "node" {
  count = 3
}

resource "scaleway_instance_server" "node" {
  count = 3
  name  = "node_${count.index}"
  type  = "DEV1-S"
  image = "ubuntu_focal"
  ip_id = scaleway_instance_ip.node[count.index].id
  provisioner "remote-exec" {
    inline = [
      "export K3S_TOKEN='${random_string.random.result}'",
      "curl -sfL https://get.k3s.io | sh -s - agent --server https://${scaleway_instance_server.master_0.public_ip}:6443",
    ]
    connection {
      host = scaleway_instance_ip.node[count.index].address
      type     = "ssh"
      user     = "root"
      agent       = true
    }
  }
  depends_on = [scaleway_instance_server.master_0]
}

resource "scaleway_instance_private_nic" "pnic01" {
    server_id          = scaleway_instance_server.master_0.id
    private_network_id = scaleway_vpc_private_network.pn_priv.id
}

resource "scaleway_instance_private_nic" "pnic02" {
    server_id          = scaleway_instance_server.master_1.id
    private_network_id = scaleway_vpc_private_network.pn_priv.id
}

resource "scaleway_instance_private_nic" "pnic03" {
    server_id          = scaleway_instance_server.master_2.id
    private_network_id = scaleway_vpc_private_network.pn_priv.id
}

resource "scaleway_instance_private_nic" "pnic_node" {
    count = 3
    server_id          = scaleway_instance_server.node[count.index].id
    private_network_id = scaleway_vpc_private_network.pn_priv.id
}

resource "scaleway_vpc_private_network" "pn_priv" {
    name = "subnet_k3s"
    tags = ["k3s", "terraform"]
}

resource "null_resource" "kubeconfig" {
  provisioner "local-exec" {
    command = <<EOT
        set -xe
        #!/bin/bash
        scp -o "StrictHostKeyChecking no" root@${scaleway_instance_server.master_0.public_ip}:/etc/rancher/k3s/k3s.yaml ./kubeconfig
        sed -i 's/127.0.0.1/${scaleway_instance_server.master_0.public_ip}/' ./kubeconfig
    EOT
    connection {
      type     = "ssh"
      user     = "root"
      host     = scaleway_instance_ip.master_0.address
    }
  }
  depends_on = [scaleway_instance_server.master_0]
}
