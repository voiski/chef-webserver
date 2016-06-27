# chef-webserver
A wrapper cookbook with the name webserver. This cookbook will setup apache2 and mysql in ubuntu, using vagrant with virtual box provider and checkout two git repos that will be the two sites.




### 1st Creating the project

- **node** :stew: Install [chef-dk](https://downloads.chef.io/chef-dk/)

> For ubuntu:
>
> ```bash
> wget --quiet --output-document=- http://example.com/path/to/package.deb && dpkg --install - `ls chef_*`
> ```

- **node** :stew: vagrant init hashicorp/precise64
- **node** :stew: vagrant plugin install vagrant-omnibus vagrant-berkshelf
- **node** :stew: [manual] Change Vagrantfile to use chef and berkshell

```ruby
  config.omnibus.chef_version = :latest
  config.berkshelf.enabled = true
```

- **node** :stew: [manual] Change Vagrantfile to have a public interface

```ruby
  # Optional, you can force to use the bridge mode, otherwise vagrant will ask you about it.
  # config.vm.network "public_network", bridge: "en0: Wi-Fi (AirPort)"
  config.vm.network "public_network"
```

- **chef** :hocho: chef generate cookbook webserver
- **chef** :hocho: [manual] Add depences to the new cookbook at the *Berksfile*

```ruby
cookbook 'apt'
cookbook 'git'
```

- **node** :stew: [manual] Add the path to the cookbook

```ruby
  config.berkshelf.berksfile_path = "webserver/Berksfile"
  config.vm.provision "chef_solo" do |chef|
    chef.add_recipe "webserver"
  end
```

- **node** :stew: vagrant up --provider virtualbox



### 2nd Configure the sites

- **chef** :hocho: [manual] Create attributes *webserver/attributes/default.rb*

```ruby
default['webserver']['sites']['chef-site']   = { fqdn: 'chef-site.avenuecode.com',   document_root: '/var/www/chef-site'  }
default['webserver']['sites']['chef-portal'] = { fqdn: 'chef-portal.avenuecode.com', document_root: '/var/www/chef-portal'}
```

- **chef** :hocho: [manual] Create template for apache configuration *webserver/templates/default/virtual.conf.erb*

```ruby
<VirtualHost *:80>
  DocumentRoot "<%= @document_root -%>"
  ServerName <%= @fqdn %>
</VirtualHost>
```

- **chef** :hocho: [manual] Add step to install mysql from ppa at *webserver/recipes/default.rb*

```ruby
apt_repository 'mysql-ppa' do
  uri          'ppa:ondrej/mysql-5.6'
  distribution node['lsb']['codename']
end

package 'mysql-server-5.6'
```

- **chef** :hocho: [manual] Add step to install and configure apache at *webserver/recipes/default.rb*

```ruby
package 'apache2'

execute 'rm /etc/apache2/sites-enabled/000-default' do
  only_if { File.exist? '/etc/apache2/sites-enabled/000-default' }
  notifies :restart, 'service[apache2]'
end

node.default['webserver']['sites'].each do |site_name, site_data|
  template "/etc/apache2/sites-available/#{site_name}.conf" do
    source 'virtual.conf.erb'
    mode '0644'
    variables(
      :document_root => site_data[:document_root],
      :fqdn => site_data[:fqdn]
    )
  end
  link "/etc/apache2/sites-enabled/#{site_name}.conf" do
    to "../sites-available/#{site_name}.conf"
  end
  directory site_data[:document_root] do
    mode '0755'
    recursive true
  end
end

service 'apache2' do
  action  [:enable, :restart]
end
```

- **chef** :hocho: [manual] Add step to load the resources of the sites at *webserver/recipes/default.rb*

```ruby
package 'git'

node.default['webserver']['sites'].keys.each do |site_name|
  git "/var/www/#{site_name}" do
    repository "https://github.com/jrvlima/#{site_name}"
    revision 'master'
    action :sync
  end
end
```

- **node** :stew: vagrant reload




### 3th Final, accessing the sites
- **node** :stew: sudo sed -i '/.* chef-portal.avenuecode.com/d' /etc/hosts
- **node** :stew: new_ip=$(vagrant ssh -c "ip address show eth1 | grep 'inet ' | sed -e 's/^.*inet //' -e 's/\/.*$//'")
- **node** :stew: sudo sed -i "$ a ${new_ip//[^([:alnum:]|\.)]/} chef-site.avenuecode.com chef-portal.avenuecode.com" /etc/hosts

> Then check the result on the browser for both links:
> - http://chef-site.avenuecode.com/
> - http://chef-portal.avenuecode.com/
