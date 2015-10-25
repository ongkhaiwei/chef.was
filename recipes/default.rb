# Cookbook Name:: websphere_application_server
# Recipe:: default
#
# (C) Copyright IBM Corporation 2014.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Installs and starts WebSphere Application Server
include_recipe "iim"

#chef_gem "pmap"
#require "pmap"
require "tempfile"
#CACHE = Chef::Config[:file_cache_path]
CACHE = node[:was][:installer][:temp]

=begin
if platform_family?('debian')
  # WAS doesn't work correctly if /bin/sh is linked to something other than bash
  execute "fix bash" do
    command 'sudo echo "dash    dash/sh boolean false" | debconf-set-selections ; dpkg-reconfigure --frontend=noninteractive dash'
  end
end

file "/etc/profile.d/websphere.sh" do
  action :create_if_missing
  #owner "root"
  #group "root"
  mode "0755"
  content <<-EOD
# Increase the file descriptor limit to support WAS
# See http://pic.dhe.ibm.com/infocenter/iisinfsv/v8r5/topic/com.ibm.swg.im.iis.found.admin.common.doc/topics/t_admappsvclstr_ulimits.html
ulimit -n 20480
EOD
end
=end

execute "LDR_CNTRL" do
    command 'echo "unset LDR_CNTRL" >> /etc/profile'
    user "root"
end
=begin
file "/etc/security/limits.d/websphere.conf" do
  action :create_if_missing
  #owner "root"
  #group "root"
  mode "0755"
  content <<-EOD
# Increase the limits for the number of open files for the pam_limits module to support WAS
# See http://pic.dhe.ibm.com/infocenter/iisinfsv/v8r5/topic/com.ibm.swg.im.iis.found.admin.common.doc/topics/t_admappsvclstr_ulimits.html
* soft nofile 20480
* hard nofile 20480
EOD
end
=end

unless ::File.exists? node[:was][:dir]
  # Download the installer(s)
  unpack_dir = ::File.join(CACHE, "was")

  directory unpack_dir do
    action :create
    owner 'root'
    #group 'root'
  end

  zip_file = node[:was][:installer][:file]

  if zip_file.nil?
    zip_uri = ::URI.parse(node[:was][:installer][:url])
    zip_filename = ::File.basename(zip_uri.path)
    zip_file = "#{unpack_dir}/#{zip_filename}" 
    remote_file zip_file do
      source node[:was][:installer][:url]
    end
  else
    zip_filename = ::File.basename(zip_file)
  end

  execute "untar" do
    cwd unpack_dir
    command "tar xf #{zip_file}"
    user "root"
  end

  # Install it
  response_file = ::File.join(CACHE, "was_setup.rsp")
  template response_file do
    source "was_setup.rsp.erb"
    owner "root"
    variables({
      :installer_dir => unpack_dir,
      :install_location => node[:was][:dir],
      :im_shared_dir => node[:was][:installer][:im_shared_dir]
    })
  end

  iim_response_file_install 'was' do 
    response_file response_file
    #master_password_file node[:ihs][:install][:masterPasswordFile] #all these default to null, and depending on your repositories security settings they might be able to remain that way. 
    #secure_storage_file node[:ihs][:install][:secureStorageFile]
    action :install
  end

end

was_bin = ::File.join(node[:was][:dir], "bin")
manage_profiles = ::File.join(was_bin, "manageprofiles.sh")
profiles = ::File.join(node[:was][:dir], "profiles")
templates = ::File.join(node[:was][:dir], "profileTemplates")

execute "configure the deployment manager profile" do
  cwd was_bin
  command "#{manage_profiles} \
    -create \
    -profileName #{node[:was][:dm][:name]} \
    -profilePath #{::File.join(profiles, node[:was][:dm][:name])} \
    -enableAdminSecurity true \
    -serverType DEPLOYMENT_MANAGER \
    -templatePath #{::File.join(templates, "management")} \
    -nodeName #{node[:was][:dm][:node_name]} \
    -cellName #{node[:was][:dm][:cell_name]} \
    -hostName #{node['fqdn']} \
    -adminUserName wasadmin \
    -adminPassword wasadmin"
  not_if { ::File.exists? ::File.join(profiles, node[:was][:dm][:name]) }
end

serverStatus = ::File.join(profiles, node[:was][:dm][:name], "bin", "serverStatus.sh")
execute "start the deployment manager #{serverStatus}" do
  # We should be able to use executables from was_bin
  cwd ::File.join(profiles, node[:was][:dm][:name], "bin")
  command ::File.join(profiles, node[:was][:dm][:name], "bin", "startManager.sh")
  # For some reason the server name is dmgr
  # Also, for some reason, this doesn't actually work...
  not_if "#{serverStatus} dmgr -username wasadmin -password wasadmin | grep STARTED"
end

=begin
template ::File.join(CACHE, "wsadmin-ldap.jy") do
  source "wsadmin-ldap.jy.erb"
  owner "root"
  group "root"
  mode "0755"
  variables({
    :ldap => node[:was][:ldap]
  })
end

execute "Use WSAdmin to connect WAS to LDAP" do
  cwd ::File.join(profiles, node[:was][:dm][:name], "bin")
  command ::File.join(profiles, node[:was][:dm][:name], "bin", "wsadmin.sh -lang jython -f #{::File.join(CACHE, "wsadmin-ldap.jy")} -conntype SOAP -user wasadmin -password wasadmin")
end
=end

execute "Restart the node and verify wasadmin still works" do
  cwd ::File.join(profiles, node[:was][:dm][:name], "bin")
  command "./stopManager.sh -username wasadmin -password wasadmin && ./startManager.sh && ./stopManager.sh -username wasadmin -password wasadmin && ./startManager.sh"
end

execute "create a managed node (profile)" do
  cwd was_bin
  command "#{manage_profiles} \
    -create \
    -profileName #{node[:was][:node][:name]} \
    -profilePath #{::File.join(profiles, node[:was][:node][:name])} \
    -enableAdminSecurity true \
    -templatePath #{::File.join(templates, "managed")} \
    -nodeName #{node[:was][:node][:node_name]} \
    -hostName #{node['fqdn']} \
    -dmgrHost #{node['fqdn']} \
    -dmgrAdminUserName wasadmin \
    -dmgrAdminPassword wasadmin"
    # -cellName #{node[:was][:node][:cell_name]} \
    # may need to specify dmgrHost, dmgrPort, dmgrAdminUserName, and dmgrAdminPassword
  not_if { ::File.exists? ::File.join(profiles, node[:was][:node][:name]) }
end

execute "start the node" do
  # We should be able to use executables from was_bin
  cwd ::File.join(profiles, node[:was][:node][:name], "bin")
  command ::File.join(profiles, node[:was][:node][:name], "bin", "startNode.sh")
  not_if "#{::File.join(profiles, node[:was][:node][:name], "bin", "serverStatus.sh")} nodeagent -profileName #{node[:was][:node][:name]} -username wasadmin -password wasadmin | grep STARTED"
end

file "#{::File.join(CACHE, 'temp.py')}" do 
  action :create_if_missing
  mode "0755"
  content <<-EOD
AdminTask.createApplicationServer('Cell01Node01',['-name', '#{node[:was][:node][:appservername]}', '-templateName', 'default'])
AdminConfig.save()
EOD
end

execute "Use WSAdmin to create Application Server" do
  cwd ::File.join(profiles, node[:was][:dm][:name], "bin")
  command ::File.join(profiles, node[:was][:dm][:name], "bin", "wsadmin.sh -lang jython -f #{::File.join(CACHE, "temp.py")} -conntype SOAP -host localhost -port 8879 -username wasadmin -password wasadmin")
end

execute "delay 30 seconds" do
  cwd ::File.join(profiles, node[:was][:dm][:name], "bin")
  command "sleep 30"
end

execute "start Application server" do 
  cwd ::File.join(profiles, node[:was][:node][:name], "bin")
  command ::File.join(profiles, node[:was][:node][:name], "bin", "startServer.sh #{node[:was][:node][:appservername]}")
end

execute "delete temp" do
  command "rm -fr #{::File.join(CACHE, "was")}"
  user "root"
end

# vi: set ft=ruby shiftwidth=2 tabstop=4 :
