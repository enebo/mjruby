class JavaSupport

  def initialize
    found = attempt_javacmd(ENV['JAVACMD']) ||
      attempt_java_home(ENV['JAVA_HOME']) ||
           resolve_native_java_home
    raise "no java_home found." unless found
  end

  def resolve_native_java_home
    native_java_home = find_native_java
    return nil unless native_java_home
    native_java_home.strip!
    if native_java_home.match(/\/bin\/java$/)
      native_java_home = file.expand_path("../..", native_java_home)
    end
    attempt_java_home(native_java_home)
  end

  def attempt_javacmd(javacmd)
    return nil unless javacmd

    @java_exe = javacmd
    java_bin = file.dirname(javacmd)
    attempt_java_home(file.dirname(java_bin))
  end

  def attempt_java_home(path)
    exe = exists_or_nil(resolve_java_exe(path))
    return nil unless dir.exists?(path) || exe

    @java_exe = exe  # perhaps double setting from attempt_javacmd but it is same value

    try_jdk_home(path) || try_jre_home(path) || try_jdk9_home(path)
  end

  def try_jdk_home(path)
    sdl = exists_or_nil(resolve_jdk_server_dl(path))
    cdl = exists_or_nil(resolve_jdk_client_dl(path))
    return nil unless cdl or sdl
    @runtime, @java_server_dl, @java_client_dl = :jdk, sdl, cdl
  end

  def is_jdk9_home?(path)
    sdl = exists_or_nil(resolve_jdk9_server_dl(path))
    return nil unless sdl
    @runtime, @java_server_dl = :jdk8, sdl
  end

  def is_jre_home?(path)
    cdl = exists_or_nil(resolve_jre_client_dl(path))
    return nil unless cdl
    @runtime, @java_client_dl = :jre, cdl
  end

  def resolve_java_exe(java_home)
    File.join(java_home, "bin", JAVA_EXE)
  end

  def resolve_jdk_server_dl(java_home)
    File.join(java_home, "jre", JavaSupport::JAVA_SERVER_DL)
  end

  def resolve_jdk9_server_dl(java_home)
    File.join(java_home, JavaSupport::JAVA_SERVER_DL)
  end

  def resolve_jdk_client_dl(java_home)
    File.join(java_home, "jre", JavaSupport::JAVA_CLIENT_DL)
  end

  def resolve_jre_client_dl(java_home)
    File.join(java_home, JavaSupport::JAVA_CLIENT_DL)
  end

  def resolve_jli_dl
    if @runtime == :jdk
      File.join(@java_home, "jre", JavaSupport::JLI_DL)
    else
      File.join(@java_home, JavaSupport::JLI_DL)
    end
  end

  def resolve_java_dls(java_opts)
    client_i = java_opts.index("-client")
    server_i = java_opts.index("-server")
    if client_i.nil? && server_i.nil?
      java_dl = @java_server_dl || @java_client_dl
    elsif server_i
      java_dl = @java_server_dl
    elsif client_i
      java_dl = @java_client_dl
    elsif server_i < client_i
      java_dl = @java_client_dl
    else
      java_dl = @java_server_dl
    end

    raise "Could not find Java native library" if java_dl.nil?

    yield java_opts.select{|o| !["-client","-server"].include?(o) }, java_dl, resolve_jli_dl
  end

  def exec_java(java_class, java_opts, ruby_opts)
    resolve_java_dls(java_opts) do |parsed_java_opts, java_dl, jli_dl|
      all_opts = parsed_java_opts + ruby_opts
      Kernel.exec_java java_dl, jli_dl, java_class, parsed_java_opts.size, *all_opts
    end
  end

  def self.is_cygwin
    false
  end

  def self.cp_delim
    # TODO Windows?
    is_cygwin ? ";" : ":"
  end

  private

  def exists_or_nil(path)
    File.exists?(path) ? path : nil
  end
end
