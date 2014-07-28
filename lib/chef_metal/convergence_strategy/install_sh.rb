require 'chef_metal/convergence_strategy/precreate_chef_objects'
require 'pathname'

module ChefMetal
  class ConvergenceStrategy
    class InstallSh < PrecreateChefObjects
      @@install_sh_cache = {}

      def initialize(convergence_options, config)
        convergence_options = Cheffish::MergedConfig.new(convergence_options, {
          :client_rb_path => '/etc/chef/client.rb',
          :client_pem_path => '/etc/chef/client.pem'
        })
        super(convergence_options, config)
        @install_sh_url = convergence_options[:install_sh_url] || 'http://www.opscode.com/chef/install.sh'
        @install_sh_path = convergence_options[:install_sh_path] || '/tmp/chef-install.sh'
        @bootstrap_env = convergence_options[:bootstrap_proxy] ? "http_proxy=#{convergence_options[:bootstrap_proxy]}" : ""
        @chef_client_timeout = convergence_options.has_key?(:chef_client_timeout) ? convergence_options[:chef_client_timeout] : 120*60 # Default: 2 hours
      end

      attr_reader :install_sh_url
      attr_reader :install_sh_path
      attr_reader :bootstrap_env

      def setup_convergence(action_handler, machine)
        super

        # Install chef-client.  TODO check and update version if not latest / not desired
        if machine.execute_always('chef-client -v').exitstatus != 0
          # TODO ssh verification of install.sh before running arbtrary code would be nice?
          @@install_sh_cache[install_sh_url] ||= Net::HTTP.get(URI(install_sh_url))
          machine.write_file(action_handler, install_sh_path, @@install_sh_cache[install_sh_url], :ensure_dir => true)
          machine.execute(action_handler, "bash -c '#{bootstrap_env} bash #{install_sh_path}'")
        end
      end

      def converge(action_handler, machine)
        super

        action_handler.open_stream(machine.node['name']) do |stdout|
          action_handler.open_stream(machine.node['name']) do |stderr|
            command_line = "chef-client"
            command_line << " -l #{config[:log_level].to_s}" if config[:log_level]
            machine.execute(action_handler, command_line,
              :stream_stdout => STDOUT,
              :stream_stderr => STDERR,
              :timeout => @chef_client_timeout)
          end
        end
      end
    end
  end
end
