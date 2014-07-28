require 'timeout'

module ChefMetal
  class Transport
    DEFAULT_TIMEOUT = 15*60

    # Execute a program on the remote host.
    #
    # == Arguments
    # command: command to run.  May be a shell-escaped string or a pre-split array containing [PROGRAM, ARG1, ARG2, ...].
    # options: hash of options, including but not limited to:
    #          :timeout => NUM_SECONDS - time to wait before program finishes (throws an exception otherwise).  Set to nil or 0 to run with no timeout.  Defaults to 15 minutes.
    #          :stream => BOOLEAN - true to stream stdout and stderr to the console.
    #          :stream => BLOCK - block to stream stdout and stderr to (block.call(stdout_chunk, stderr_chunk))
    #          :stream_stdout => FD - FD to stream stdout to (defaults to IO.stdout)
    #          :stream_stderr => FD - FD to stream stderr to (defaults to IO.stderr)
    #          :read_only => BOOLEAN - true if command is guaranteed not to change system state (useful for Docker)
    def execute(command, options = {})
      raise "execute not overridden on #{self.class}"
    end

    def read_file(path)
      raise "read_file not overridden on #{self.class}"
    end

    def write_file(path, content)
      raise "write_file not overridden on #{self.class}"
    end

    def download_file(path, local_path)
      IO.write(local_path, read_file(path))
    end

    def upload_file(local_path, path)
      write_file(path, IO.read(local_path))
    end

    def make_url_available_to_remote(local_url)
      raise "make_url_available_to_remote not overridden on #{self.class}"
    end

    def disconnect
      raise "disconnect not overridden on #{self.class}"
    end

    def available?
      raise "available? not overridden on #{self.class}"
    end

    # Config hash, including :log_level and :logger as keys
    def config
      raise "config not overridden on #{self.class}"
    end

    protected

    # Helper to implement stdout/stderr streaming in execute
    def stream_chunk(options, stdout_chunk, stderr_chunk)
      if options[:stream].is_a?(Proc)
        options[:stream].call(stdout_chunk, stderr_chunk)
      else
        if stdout_chunk
          if options[:stream_stdout]
            Chef::Log.info(stdout_chunk)
            #puts stdout_chunk
            #options[:stream_stdout].print stdout_chunk
          elsif options[:stream] || config[:log_level] == :debug
            STDOUT.print stdout_chunk
          end
        end
        if stderr_chunk
          if options[:stream_stderr]
            options[:stream_stderr].print stderr_chunk
          elsif options[:stream] || config[:log_level] == :debug
            STDERR.print stderr_chunk
          end
        end
      end
    end

    def with_execute_timeout(options, &block)
      Timeout::timeout(execute_timeout(options), &block)
    end

    def execute_timeout(options)
      options.has_key?(:timeout) ? options[:timeout] : DEFAULT_TIMEOUT
    end
  end
end
