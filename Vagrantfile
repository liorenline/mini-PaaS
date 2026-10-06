Vagrant.configure("2") do |config|
  config.vm.box = "utm/ubuntu-24.04" # for utm

  config.vm.provider "utm" do |utm|
    utm.cpus = 2
    utm.memory = 2048  
  end
  config.vm.network "forwarded_port", guest: 3000, host: 3000

end
