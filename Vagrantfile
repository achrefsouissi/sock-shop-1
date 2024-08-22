# Define node roles and configurations
NODE_ROLES = ["server-0", "agent-0", "agent-1"]
NODE_BOXES = ['generic/ubuntu2004'] * 3  # Nombre de machines mis à jour
NODE_CPUS = 2
NODE_MEMORY = 3072 # Augmenté à 4096 Mo (4 Go)
NETWORK_PREFIX = "10.10.10"

def provision(vm, role, node_num)
  vm.box = NODE_BOXES[node_num]
  vm.hostname = role
  node_ip = "#{NETWORK_PREFIX}.#{100 + node_num}"

  # Configurer le réseau privé
  vm.network "private_network", ip: node_ip, netmask: "255.255.255.0"

  # Configurer le réseau public pour l'accès à Internet
  vm.network "public_network", bridge: "wlp3s0" # Utilisation de l'interface réseau Wi-Fi

  vm.provision "ansible", run: 'once' do |ansible|
    ansible.compatibility_mode = "2.0"
    ansible.playbook = "playbooks/site.yml"
    ansible.groups = {
      "server" => ["server-0"],
      "agent" => ["agent-0", "agent-1"],
      "k3s_cluster:children" => ["server", "agent"],
    }
    ansible.extra_vars = {
      k3s_version: "v1.26.9+k3s1",
      api_endpoint: "#{NETWORK_PREFIX}.100",  # IP du serveur
      token: "myvagrant",
      extra_server_args: "--node-external-ip #{node_ip} --flannel-iface eth1",
      extra_agent_args: "--node-external-ip #{node_ip} --flannel-iface eth1",
    }
  end
end

Vagrant.configure("2") do |config|
  config.vm.provider "libvirt" do |v|
    v.cpus = NODE_CPUS
    v.memory = NODE_MEMORY
  end
  config.vm.provider "virtualbox" do |v|
    v.cpus = NODE_CPUS
    v.memory = NODE_MEMORY
    v.linked_clone = true
  end
  
  NODE_ROLES.each_with_index do |name, i|
    config.vm.define name do |node|
      provision(node.vm, name, i)
    end
  end
end

