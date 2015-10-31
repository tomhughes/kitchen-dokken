# -*- encoding: utf-8 -*-
#
# Author:: Sean OMeara (<sean@chef.io>)
#
# Copyright (C) 2015, Sean OMeara
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require 'kitchen'
require 'kitchen/provisioner/chef_zero'

module Kitchen
  module Provisioner
    # @author Sean OMeara <sean@chef.io>
    class Dokken < Kitchen::Provisioner::ChefZero
      kitchen_provisioner_api_version 2

      plugin_version Kitchen::VERSION

      # (see Base#call)
      def call(state)
        # transfer files
        begin
          create_sandbox
          sandbox_dirs = Dir.glob(File.join(sandbox_path, '*'))

          instance.transport.connection(state) do |conn|
            info("Transferring files to #{instance.to_str}")
            conn.upload(sandbox_dirs, config[:root_path])
            debug('Transfer complete')
            conn.execute(run_command)
          end          
        rescue Kitchen::Transport::TransportFailed => ex
          raise ActionFailed, ex.message
        ensure
          cleanup_sandbox
        end

        # converge node
        instance_name = state[:instance_name]

        puts 'why am I not in color?'
        
        c = Docker::Container.get(runner_container_name)
        new_image = c.commit          
        new_image.tag('repo' => "someara/#{instance_name}", 'tag' =>'latest', 'force' => 'true')        
      end

      private
      
      def run_command
        cmd = '/opt/chef/embedded/bin/chef-client -z'
        cmd << ' -c /tmp/kitchen/client.rb'
        cmd << ' -j /tmp/kitchen/dna.json'
        cmd << ' -F doc'
      end

      def runner_container_name
        "#{instance.name}-runner"
      end
    end
  end
end