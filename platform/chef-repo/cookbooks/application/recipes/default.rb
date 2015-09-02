#
# Cookbook Name:: application
# Recipe:: default
#
# Copyright (C) 2015 YOUR_NAME
#
# All rights reserved - Do Not Redistribute
#

# proxy for New Relic
node.set['newrelic']['proxy']['host'] = node['base']['metadata']['stack']['proxy_host']
node.set['newrelic']['proxy']['port'] = node['base']['metadata']['stack']['proxy_port']
