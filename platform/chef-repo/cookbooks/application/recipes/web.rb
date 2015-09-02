
node.set['nginx']['ssl']['key'] = '/dev/shm/server.key'
node.set['nginx']['ssl']['cert'] = '/dev/shm/server.crt'

include_recipe "dnsmasq"
include_recipe "nginx"

if node['application']['static-assets']['enabled'] == true
	include_recipe "aws_simple_s3"

	package "unzip" do
		action :install
	end

	directory node['application']['static-assets']['path'] do
		mode '0755'
		owner node['base']['user']
  		group node['base']['group']
		recursive true
	end 

	require 'uri'
	s3path = node['base']['metadata']['deployment']['artifact_url']
	uri = URI.parse(s3path)
	s3path = File.basename(uri.path)

	aws_simple_s3_file "/app/web.zip" do
	  s3path "#{s3path}/#{node['application']['static-assets']['artifact']}"
	  bucket node['base']['metadata']['deployment']['s3bucket']
	end

	execute "static-assets-chown" do
	  command "chown #{node['base']['user']}:#{node['base']['group']} /app/web.zip"
	  action :run
	end

	execute "static-assets-unzip" do
	  cwd "/app/"
	  command "unzip -o web.zip -d #{node['application']['static-assets']['path']}"
	  user node['base']['user']
	  group node['base']['group']
	  action :run
	  notifies :run, 'execute[static-assets-remove_zip]'
	end

	execute 'static-assets-remove_zip' do
		cwd '/app'
		command 'rm -f web.zip'
		action :nothing
	end
	

end

nginx_vhost 'default_application' do
end
