require "logger"
require "option_parser"
require "colorize"
require "yaml"

# * **converter**: specify an alternate type for parsing and generation. The converter must define `from_yaml(YAML::PullParser)` and `to_yaml(value, YAML::Builder)` as class methods.
# def self.from_yaml(ctx : YAML::ParseContext, node : YAML::Nodes::Node) : Time
# def self.to_yaml(value : Time, yaml : YAML::Nodes::Builder)

module Path::StringConverter
  def self.from_yaml(ctx, node) : Path
    unless node.is_a?(YAML::Nodes::Scalar)
      node.raise "Expected scalar, not #{node.class}"
    end
    Path.new node.value.to_s
  end

  def self.to_yaml(value, yaml)
    yaml.scalar value
  end
end

module Edraj
  LOGGER = Logger.new(STDOUT)
  LOGGER.level = Logger::DEBUG

  def self.logger
    LOGGER
  end

  class Config
    include YAML::Serializable
    property port = 3000
    property host = "localhost"
    @[YAML::Field(converter: Path::StringConverter)]
    property data_path = Path.new "~/edraj/"
    @[YAML::Field(converter: Path::StringConverter)]
    property run_path = Path.new "/tmp/edraj/"
    property jwt_secret : String
  end

  def self.load_config : Config
    _port = 0
    _host = ""
    _run_path = ""
    _data_path = ""

    config_file = "./config.yml"

    OptionParser.parse do |parser|
      parser.banner = "Usage: Edrage [arguments]"
      parser.on("-p PORT", "--port=PORT", "Poort to bind to. (default: 3000)") { |p| _port = p.to_i { 0 } }
      parser.on("-l HOSTNAME", "--listen=HOSTNAME", "Interface to bind to. (default: localhost )") { |p| _host = p }
      parser.on("-r RUN_PATH", "--run-path=RUN_PATH", "The intermediate / caching runtime files path. (default: /tmp/edraj)") { |p| _run_path = p }
      parser.on("-d DATA_PATH", "--datapath=DATA_PATH", "Folder where all information is persisted. (default: ~/edraj)") { |p| _data_path = p }
      parser.on("-c FILE", "--config=FILE", "Specifies a yaml file to load for configuration (default: 'config.yml')") { |p| config_file = p }
      parser.on("-h", "--help", "Show this help") { puts parser; exit 0 }
    end

    if !File.exists?(config_file)
      puts "Unable to read config file #{config_file}".colorize.red
      exit
    end

    config = Config.from_yaml File.read config_file

    config.port = _port unless _port == 0
    config.host = _host unless _host.empty?
    config.run_path = Path.new _run_path unless _run_path.empty?
    config.data_path = Path.new _data_path unless _data_path.empty?

    puts "Loaded config".colorize.magenta
    puts config.to_yaml.colorize.cyan

    config
  end

  CONFIG = load_config

  def self.settings
    CONFIG
  end
end
