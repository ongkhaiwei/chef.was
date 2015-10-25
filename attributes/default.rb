# Cookbook Name:: websphere_application_server
# Attributes:: default
#
# (C) Copyright IBM Corporation 2014.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and

include_attribute "iim"

default[:was][:dir] = '/opt/IBM/WebSphere/AppServer'
default[:was][:installer][:im_shared_dir] = '/opt/IBM/IMShared' # FIXME this should come from the im chef attrs

default[:was][:installer][:url] = nil

default[:was][:installer][:temp] = '/tmp'

default[:was][:dm][:name] = "Dmgr01"
default[:was][:dm][:cell_name] = "Cell01"
default[:was][:dm][:node_name] = "Cell01Manager"

default[:was][:node][:name] = "Cell01Node01"
default[:was][:node][:cell_name] = "Cell01"
default[:was][:node][:node_name] = "Cell01Node01"
default[:was][:node][:appservername] = "server1"

default[:was][:ldap][:id] = "FederatedLdap"
default[:was][:ldap][:host] = "" # e.g. ldap.example.com
default[:was][:ldap][:port] = 389
default[:was][:ldap][:bind_dn] = "" # e.g. cn=root
default[:was][:ldap][:bind_password] = ""
default[:was][:ldap][:server_type] = "" # e.g. IDS,ZOSDS,DOMINO,NDS,SUNONE,AD,ADAM,CUSTOM
default[:was][:ldap][:login_properties] = ["mail", "uid"]
default[:was][:ldap][:base_dn] = "" # e.g. dc=example,dc=com
default[:was][:ldap][:entities] = [
  { :name => "", # e.g. "PersonAccount"
    :object_classes => [], # e.g. ["user", "person"]
    :search_bases => [], # e.g. ["cn=Users,dc=example,dc=com"]
    :search_filter => "" # e.g. "(ObjectCategory=User)"
  }
]

