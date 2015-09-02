
# Secrets Wrapper recipe

node.set['secrets']['kms_region'] = node['base']['metadata']['stack']['region']
node.set['secrets']['secrets_s3_bucket'] = node['base']['metadata']['deployment']['secretss3bucket']
node.set['secrets']['kms_cmk_id'] = node['base']['metadata']['deployment']['secretskmskey'].match(/key\/(.*)/)[1]
node.set['secrets']['prefix'] = node['base']['metadata']['deployment']['secretsprefix']

#if node['roles'].include? 'admin'
#	node.set['secrets']['list'] = [ "#{node['base']['metadata']['deployment']['product']}/#{node[:environment]}/rds_mysql/master",
#									"#{node['base']['metadata']['deployment']['product']}/#{node[:environment]}/rds_rds/migrate" ]
#end

include_recipe 'secrets::default'

# Deal with retrieved secrets
app_secrets = { 'server.key' => 'web.key', 
           		'server.crt' => 'web.cer', 
           		'Intuit_SSL_Root_CA.pem' => 'Intuit_SSL_Root_CA.pem',
           		'cto-aws-forwarder.pem' => 'cto-aws-forwarder.pem',
           		'sbg-aws-forwarder.pem' => 'sbg-aws-forwarder.pem'
         } 

app_secrets.each do  |file_name,name|
	file "/dev/shm/#{file_name}" do
		action :create
		owner 'root'
		group 'root'
		mode '600'
		content node['secrets']['data'][name]
		sensitive true
	end
end

node.set['newrelic']['license_key'] = node['secrets']['data']['newrelic_license'].chomp

# Splunk links
['sbg-aws-preprod-forwarder.pem', 'sbg-aws-prod-forwarder.pem'].each do |file|
	link "/dev/shm/#{file}" do
		to '/dev/shm/sbg-aws-forwarder.pem'
	end
end
