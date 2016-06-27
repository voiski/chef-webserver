#
# Cookbook Name:: webserver
# Recipe:: default
#
# Copyright (c) 2016 The Authors, All Rights Reserved.

# Install MySQL from PPA
apt_repository 'mysql-ppa' do
  uri          'ppa:ondrej/mysql-5.6'
  distribution node['lsb']['codename']
end

package 'mysql-server-5.6'

# Install apache2 and configure to the sites
package 'apache2'

execute 'mv /etc/apache2/sites-enabled/000-default /etc/apache2/sites-available/000-default' do
  only_if { File.exist? '/etc/apache2/sites-enabled/000-default' }
  notifies :restart, 'service[apache2]'
end

node.default['webserver']['sites'].each do |site_name, site_data|
  template '/etc/apache2/sites-enabled/#{site_name}.conf' do
    source 'virtual.conf.erb'
    mode '0644'
    variables(
      :document_root => site_data[:document_root],
      :fqdn => site_data[:fqdn]
    )
  end
  directory site_data[:document_root] do
    mode '0755'
    recursive true
  end
end

service 'apache2' { action  [:enable, :restart] }



# Load the site resources
package 'git'

node.default['webserver']['sites'].keys.each do |site_name|
  git "/var/www/#{site_name}" do
    repository "https://github.com/jrvlima/#{site_name}"
    revision 'master'
    action :sync
  end
end
