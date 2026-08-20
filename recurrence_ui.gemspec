require_relative "lib/recurrence_ui/version"

Gem::Specification.new do |spec|
  spec.name        = "recurrence_ui"
  spec.version     = RecurrenceUi::VERSION
  spec.authors     = ["Katya German"]
  spec.email       = ["assoly@gmail.com"]
  spec.homepage    = "https://github.com/assoly/recurrence_ui" 
  spec.summary     = "UI component for IceCube schedule generation in Rails."
  spec.description = "Provides ViewComponents and Stimulus controllers to build flexible event recurrence schedules using IceCube."
  spec.license     = "MIT"

  # spec.metadata["allowed_push_host"] = "https://rubygems.org"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.md"]
  end

  # ==========================================
  # Основные (Runtime) зависимости
  # ==========================================
  
  # Rails & Core UI framework
  spec.add_dependency "rails", ">= 7.1.0"
  spec.add_dependency "view_component", ">= 3.0"
  
  # Работа с расписаниями
  spec.add_dependency "ice_cube", "~> 0.16"
  
  # Internationalization (I18n) support
  spec.add_dependency "i18n", ">= 1.14"
  spec.add_dependency "rails-i18n"
  
  # ==========================================
  # Зависимости для разработки и тестирования (Опционально)
  # ==========================================
  spec.add_development_dependency "sqlite3"
  spec.add_development_dependency "rspec-rails"
end