package "unzip" do
  action :install
end

package "dos2unix" do
  action :install
end

if node['application']['use_local_memcached'] == true
  include_recipe 'memcached'
end

directory "/var/log/tomcat-#{node['base']['metadata']['deployment']['product']}" do
  owner 'app'
  group 'app'
  mode '0750'
  action :create
end

link "/usr/local/tomcat" do
  to "/app/tomcat-#{node['base']['metadata']['deployment']['product']}"
end

template "/tmp/deploy.tomcat.sh" do
  source "#{node['tomcat']['tomcat_flavor']}/fms.tomcat.sh.erb"
  mode "0755"
  owner "root"
  group "root"
end

execute "/tmp/deploy.tomcat.sh" do
 cwd "/tmp"
 command "dos2unix /tmp/deploy.tomcat.sh ; /tmp/deploy.tomcat.sh -a #{node['base']['metadata']['deployment']['artifact_url']} -e #{node['base']['metadata']['deployment']['environment']} -a #{node['base']['metadata']['deployment']['product']} -A && touch /tmp/tomcat-run-once"
 #creates "/tmp/tomcat-run-once"
 action :run
end

template "/dev/shm/setenv.sh" do
  source "#{node['tomcat']['tomcat_flavor']}/setenv.sh.erb"
  mode "0755"
  owner "app"
  group "app"
end

link "/usr/local/tomcat/bin/setenv.sh" do
  to "/dev/shm/setenv.sh"
end

execute "dos2unix-setenv" do
 cwd "/tmp"
 command "/usr/bin/dos2unix /usr/local/tomcat/bin/setenv.sh"
 action :run
end

template "/dev/shm/server.xml" do
  source "#{node['tomcat']['tomcat_flavor']}/server.xml.erb"
  mode "0444"
  owner "app"
  group "app"
end

link "/usr/local/tomcat/conf/server.xml" do
  to "/dev/shm/server.xml"
end

execute "mv-ssl-cert" do
 cwd "/tmp"
 command "mv /usr/local/tomcat/conf/ssl-cert.jks /dev/shm/ssl-cert.jks"
 creates "/dev/shm/ssl-cert.jks"
 action :run
end

link "/usr/local/tomcat/conf/ssl-cert.jks" do
  to "/dev/shm/ssl-cert.jks"
end

template "/dev/shm/newrelic.yml" do
  source "#{node['tomcat']['tomcat_flavor']}/newrelic.yml.erb"
  mode "0444"
  owner "app"
  group "app"
end

file "/usr/local/tomcat/newrelic/newrelic.yml" do
  action :delete
end

link "/usr/local/tomcat/newrelic/newrelic.yml" do
  to "/dev/shm/newrelic.yml"
end

execute "start-tomcat" do
  command "/etc/init.d/tomcat-#{node['base']['metadata']['deployment']['product']} restart"
  action :run
end
