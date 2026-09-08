# lib/generators/recurrence_ui/views_generator.rb
require "rails/generators/base"

module RecurrenceUi
  module Generators
    class ViewsGenerator < Rails::Generators::Base
      source_root File.expand_path("../../../..", __FILE__)

      desc "Copies recurrence_ui views to your application for customization"

      def copy_views
        # 1. Copy main component template to app/components/recurrence_ui/
        copy_file(
          "app/components/recurrence_ui/picker_component.html.erb",
          "app/components/recurrence_ui/picker_component.html.erb"
        )

        # 2. Copy all partials from app/views/recurrence_ui/ to app/views/recurrence_ui/
        directory(
          "app/views/recurrence_ui",
          "app/views/recurrence_ui"
        )
      end
    end
  end
end