Vagrant.configure("2") do |config|
  config.vm.box = "ubuntu/trusty64"

  # Turn off Shared Folders
  config.vm.synced_folder ".", "/vagrant", id: "vagrant-root", disabled: true

  # Begin Services Box
  config.vm.define "services" do |services|
    services.vm.hostname = "ccie-services"
    services.vm.provision :shell, path: "vagrant_init_services.sh"
    services.vm.provider "virtualbox" do |v|
      v.cpus = 2
      v.memory = 2048
    end

    services.vm.network "private_network", ip: "192.168.205.10"
    # MongoDB
    services.vm.network :forwarded_port, guest: 27017, host: 27017
    # Replicated Console
    services.vm.network :forwarded_port, guest: 8800, host: 8800
    # HTTP
    services.vm.network :forwarded_port, guest: 80, host: 80
    # HTTPS
    services.vm.network :forwarded_port, guest: 443, host: 443
    # By Default Vagrant will forward port guest:22 -> host:2222
  end
  # End Services Box

  # Begin Builder Box
  config.vm.define "builder" do |builder|
    builder.vm.hostname = "ccie-builder"
    builder.vm.provision :shell, path: "vagrant_init_builder.sh"

    builder.vm.provider "virtualbox" do |v|
      v.cpus = 6
      v.memory = 8192
    end

    builder.vm.network "private_network", ip: "192.168.205.11"
  end
  # End Builder Box
end
