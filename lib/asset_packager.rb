require 'tsort'
require 'tempfile'

class AssetPackager
  require 'sheller'
  
  # Dependency graph
  class Dep < Hash
    include TSort
    alias tsort_each_node each_key
    
    def tsort_each_child(node, &block)
      fetch(node, []).each(&block)
    end
    
    def self.from_array(array)
      array.inject(Dep.empty) { |d,e| d.merge(e => []) }
    end
    
    def self.empty
      new()
    end
    
    def +(dep)
      merge(dep) { |e, d0, d1| d0 | d1 }
    end
  end
  
  def initialize options = {}
    @target = options[:target]
    @includes = Array(options[:includes]).map { |d| Dir[d] }.flatten.sort
    @excludes = Array(options[:excludes]).map { |d| Dir[d] }.flatten
    @dependencies = options.fetch(:dependencies, {})
    closure = @dependencies.to_a.flatten.map { |d| Dir[d] }.flatten # transitive closure of dependency graph
    @explicit_includes, @implicit_includes = (@includes - @excludes).partition do |filename|
      closure.include?(filename)
    end
  end
  
  # def to_s
  #   package! if dirty?
  #   File.read(target)
  # end
  
  def target(options = {})
    @target &&
      File.join(
        options.fetch(:target_path, File.dirname(@target)),
        File.basename(@target)
      )
  end
  
  def dirty?
    !FileUtils.uptodate?(target, contents)
  end
  
  def contents(options = {})
    (
      (
        (Dep.from_array(@explicit_includes) + @dependencies).tsort + 
        @implicit_includes.sort
      ) - [ target(options) ]
    ).compact.uniq
  end
  
  def package!(options = {})
    raise NoTargetSpecifiedError unless target
  end
  
  def self.from_manifest(path)
    instance = new(parse_manifest(path))
    AssetPackager.instances_from_manifests << instance
    instance
  end
  
  def self.instances_from_manifests
    @instances_from_manifests ||= []
  end
  
  def self.vendor_jar(jar_name)
    File.expand_path(File.join(File.dirname(__FILE__), ('../vendor/%s.jar' % jar_name)))
  end
  
  private
  def self.parse_manifest(path)
    yaml         = YAML.load_file(path).symbolize_keys
    prefix       = yaml.fetch(:prefix, '')
    target       = File.join(prefix, yaml[:target]) or raise ArgumentError, "No target defined."
    add_prefix   = lambda { |path| File.join(prefix, path) }
    
    dependencies = (yaml[:dependencies] || {}).inject({}) do |m,(k,v)|
                       m.merge add_prefix[k] => (v || []).map(&add_prefix)
                     end
    
    yaml.merge(
      :target       => target,
      :includes     => Array(yaml[:includes]).map(&add_prefix),
      :excludes     => Array(yaml[:excludes]).map(&add_prefix),
      :dependencies => dependencies
    )
  end
  
  class NoTargetSpecifiedError < StandardError
  end
end
