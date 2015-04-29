class Elasticsearch14 < Formula
  homepage "https://www.elastic.co/products/elasticsearch"
  url "https://download.elastic.co/elasticsearch/elasticsearch/elasticsearch-1.4.4.tar.gz"
  sha256 "a3158d474e68520664debaea304be22327fc7ee1f410e0bfd940747b413e8586"

  bottle do
    root_url "https://homebrew.bintray.com/bottles-versions"
    cellar :any
    sha256 "006b25e5ab46dda1e5cf5aa3056e6fde7bb9b4898691d12ab3e5c58326ff1178" => :yosemite
    sha256 "9fae4f91acb8cb705cca7101628e550277bbdf37676f8408f0e7740a6c1ec6b7" => :mavericks
    sha256 "c1c92e90c30eb09984eabd8829b43380bed03379bcb81f3f5a6273773c014d07" => :mountain_lion
  end

  depends_on :java => "1.7+"

  def cluster_name
    "elasticsearch_#{ENV["USER"]}"
  end

  def install
    # Remove Windows files
    rm_f Dir["bin/*.bat"]
    rm_f Dir["bin/*.exe"]

    # Move libraries to `libexec` directory
    libexec.install Dir["lib/*.jar"]
    (libexec/"sigar").install Dir["lib/sigar/*.{jar,dylib}"]

    # Install everything else into package directory
    prefix.install Dir["*"]

    # Remove unnecessary files
    rm_f Dir["#{lib}/sigar/*"]

    # Set up Elasticsearch for local development:
    inreplace "#{prefix}/config/elasticsearch.yml" do |s|
      # 1. Give the cluster a unique name
      s.gsub!(/#\s*cluster\.name\: elasticsearch/, "cluster.name: #{cluster_name}")

      # 2. Configure paths
      s.sub!(%r{#\s*path\.data: /path/to.+$}, "path.data: #{var}/elasticsearch/")
      s.sub!(%r{#\s*path\.logs: /path/to.+$}, "path.logs: #{var}/log/elasticsearch/")
      s.sub!(%r{#\s*path\.plugins: /path/to.+$}, "path.plugins: #{var}/lib/elasticsearch/plugins")

      # 3. Bind to loopback IP for laptops roaming different networks
      s.gsub!(/#\s*network\.host\: [^\n]+/, "network.host: 127.0.0.1")
    end

    inreplace "#{bin}/elasticsearch.in.sh" do |s|
      # Configure ES_HOME
      s.sub!(%r{#\!/bin/sh\n}, "#!/bin/sh\n\nES_HOME=#{prefix}")
      # Configure ES_CLASSPATH paths to use libexec instead of lib
      s.gsub!(%r{ES_HOME/lib/}, "ES_HOME/libexec/")
    end

    inreplace "#{bin}/plugin" do |s|
      # Add the proper ES_CLASSPATH configuration
      s.sub!(/SCRIPT="\$0"/, %(SCRIPT="$0"\nES_CLASSPATH=#{libexec}))
      # Replace paths to use libexec instead of lib
      s.gsub!(%r{\$ES_HOME/lib/}, "$ES_CLASSPATH/")
    end

    # Move config files into etc
    (etc/"elasticsearch").install Dir[prefix/"config/*"]
    (prefix/"config").rmtree
  end

  def post_install
    # Make sure runtime directories exist
    (var/"elasticsearch/#{cluster_name}").mkpath
    (var/"log/elasticsearch").mkpath
    (var/"lib/elasticsearch/plugins").mkpath
    ln_s etc/"elasticsearch", prefix/"config"
  end

  def caveats; <<-EOS.undent
    Data:    #{var}/elasticsearch/#{cluster_name}/
    Logs:    #{var}/log/elasticsearch/#{cluster_name}.log
    Plugins: #{var}/lib/elasticsearch/plugins/
    Config:  #{etc}/elasticsearch/
    EOS
  end

  plist_options :manual => "elasticsearch --config=#{HOMEBREW_PREFIX}/opt/elasticsearch14/config/elasticsearch.yml"

  def plist; <<-EOS.undent
      <?xml version="1.0" encoding="UTF-8"?>
      <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
      <plist version="1.0">
        <dict>
          <key>KeepAlive</key>
          <true/>
          <key>Label</key>
          <string>#{plist_name}</string>
          <key>ProgramArguments</key>
          <array>
            <string>#{HOMEBREW_PREFIX}/bin/elasticsearch</string>
            <string>--config=#{prefix}/config/elasticsearch.yml</string>
          </array>
          <key>EnvironmentVariables</key>
          <dict>
            <key>ES_JAVA_OPTS</key>
            <string>-Xss200000</string>
          </dict>
          <key>RunAtLoad</key>
          <true/>
          <key>WorkingDirectory</key>
          <string>#{var}</string>
          <key>StandardErrorPath</key>
          <string>/dev/null</string>
          <key>StandardOutPath</key>
          <string>/dev/null</string>
        </dict>
      </plist>
    EOS
  end

  test do
    system "#{bin}/plugin", "--list"
  end
end
