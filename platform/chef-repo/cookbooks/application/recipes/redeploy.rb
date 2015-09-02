## Recipe for redeployment purpose

template "/usr/local/bin/redeploy.sh" do
  source "redeploy.sh.erb"
  mode "0700"
end

node.set['cfn-hup']['stack_name'] = node['base']['metadata']['stack']['name']
node.set['cfn-hup']['hook_name'] = "redeploy_#{node['base']['metadata']['instance_role']['role']}"
node.set['cfn-hup']['resource_path'] = "Resources.#{node['base']['metadata']['stack']['resource_name']}"
node.set['cfn-hup']['triggers'] = 'post.update'
node.set['cfn-hup']['action'] = '/usr/local/bin/redeploy.sh'

include_recipe 'cfn-hup'
