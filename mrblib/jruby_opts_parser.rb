class JRubyOptsParser

  def self.parse!(opts)
    p = new(opts)
    raise ArgumentError.new("Invalid CLI Options") unless p.valid?
    p
  end

  attr_reader :ruby_opts
  attr_reader :jruby_opts
  attr_reader :java_cmd
  attr_reader :classpath
  attr_reader :java_encoding

  def initialize(opts)
    @raw_opts = opts
    @java_opts = []
    @ruby_opts = []
    @classpath = []
    parse(opts)
  end

  def valid?
    @valid
  end

  def java_mem
    @java_mem || '-Xmx500m'
  end

  attr_reader :java_mem_min

  def java_stack
    @java_stack || '-Xss2048k'
  end

  def java_opts
    [java_mem, java_mem_min, java_stack].compact + @java_opts
  end

  private

  def parse(opts)
    while !opts.empty? do
      opt = opts.shift
      case opt
      when /^-J/
        java_opt = opt[2..-1]
        case java_opt
        when /^-Xmx/
          @java_mem = java_opt
        when /^-Xms/
          @java_mem_min = java_opt
        when /^-Xss/
          @java_stack = java_opt
        when ''
          # exec?
          puts "(Prepend -J in front of these options when using 'jruby' command)"
          @valid = false
          return
        when '-X'
          # exec?
          puts "(Prepend -J in front of these options when using 'jruby' command)"
          @valid = false
          return
        when /(-classpath)|(-cp)/
          @classpath << opts.shift
        else
          case java_opt
          when /^-ea/
            verify_java = true
          when /^-Dfile.encoding=/
            java_encoding = java_opt
          end
          @java_opts << java_opt
        end
      when /(^-X.*\..*\..*\..*)|(-X.*\?)/
        # wtf
      when /^-X/
        @ruby_opts << opt
      when /^((-C)|(-e)|(-I)|(-S))/
        @ruby_opts << opt
        @ruby_opts << opts.shift
      when /^((-e)|(-I)|(-S)).*/
        @ruby_args << opt
      when "--manage"
        @java_opts << "-Dcom.sun.management.jmxremote"
        @java_opts << "-Djruby.management.enabled=true"
      when "--headless"
        @java_opts << "-Djava.awt.headless=true"
      # when "--jdb"
      #   @java_cmd = JavaSupport.resolve_java_command("jdb")
      #   @java_opts += ["-sourcepath", "$JRUBY_HOME/lib/ruby/1.9:."]
      when "--dev"
        @java_opts << "-XX:+TieredCompilation"
        @java_opts << "-XX:TieredStopAtLevel=1"
        @java_opts << "-Djruby.compile.mode=OFF"
        @java_opts << "-Djruby.compile.invokedynamic=false"
      when "--sample"
        @java_opts << "-Xprof"
      when "--1.8"
       puts "warning: --1.8 ignored"
      when "--1.9"
        puts "warning: --1.9 ignored"
      when "--2.0"
        puts "warning: --2.0 ignored"
      when "--"
        # Abort processing on the double dash
        opts.clear
      when "-.*"
        # send the rest of the options to Ruby
        @ruby_opts += opts
        opts.clear
      when ".*"
        # Abort processing on first non-opt arg
        opts.clear
      end
    end
    @valid = true
  end
end
