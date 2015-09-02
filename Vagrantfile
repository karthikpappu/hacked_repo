# -*- mode: ruby -*-
# vi: set ft=ruby :
Vagrant.configure("2") do |config|
  config.vm.box = "centos-6.4-x86_64"
  config.vm.box_url = "http://fmsscm.corp.intuit.net/fms-build/job/bento-packer/16/artifact/builds/virtualbox/centos-6.5.box"
  (1..1).each do |i|
    vmname = "node#{i}"
    config.vm.define vmname.to_sym do |node_conf|
      node_conf.vm.host_name = vmname
      node_conf.vm.provider "virtualbox" do |v|
         v.memory = 1024
      end
      node_conf.vm.provision "shell", inline: "echo node#{i}"
      node_conf.vm.provision "shell", inline: "curl -L https://www.chef.io/chef/install.sh | bash"
      #node_conf.vm.provision :salt do |salt|
        #salt.run_highstate = true
        #salt.minion_config = "minion"
      #end
      node_conf.vm.provision :chef_solo do |chef|
        chef.add_recipe 'yum'
        chef.add_recipe 'awscli'
        chef.add_recipe 'maven'
        # ... other recipes
        chef.json = {
          yum: { version: '3.1.4' }
        }
      end
    end
  end
end
