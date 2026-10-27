require_relative "lib/recurrence_ui/version"

Gem::Specification.new do |spec|
  spec.name        = "recurrence_ui"
  spec.version     = RecurrenceUi::VERSION
  spec.authors     = ["Katerina German"]
  spec.email       = ["assoly@gmail.com"]
  spec.homepage    = "https://github.com/assoly/recurrence_ui" 
  spec.summary     = "UI component for IceCube schedule generation in Rails."
  spec.description = "Provides ViewComponents and Stimulus controllers to build flexible event recurrence schedules using IceCube."
  spec.license     = "MIT"

  # Minimum supported Ruby version
  spec.required_ruby_version = ">= 3.1.0"

  # Metadata (removed duplicate homepage_uri since spec.homepage covers it)
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"]   = "#{spec.homepage}/blob/main/CHANGELOG.md"

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.md"]
  end

  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # ==========================================
  # Main (Runtime) dependencies (bounded)
  # ==========================================
  spec.add_runtime_dependency "rails",          "~> 7.1", ">= 7.1.0"
  spec.add_runtime_dependency "view_component", "~> 3.0"
  spec.add_runtime_dependency "ice_cube",       "~> 0.16"
  spec.add_runtime_dependency "i18n",           "~> 1.14"
  spec.add_runtime_dependency "rails-i18n",     "~> 7.0"
  
  # ==========================================
  # Development and test dependencies (bounded)
  # ==========================================
  spec.add_development_dependency "sqlite3",     "~> 1.6"
  spec.add_development_dependency "rspec-rails", "~> 6.0"
end