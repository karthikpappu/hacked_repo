
## Admin server recipe
## Customize this recipe for making it fit your needs

template "/dev/shm/configure.sh" do
  source "admin/configure.sh.erb"
  mode "0700"
  notifies :run, 'execute[configure_admin]'
end

execute "configure_admin" do
  cwd "/"
  command "/usr/bin/env bash /dev/shm/configure.sh"
  action :nothing
end
