# Recurrence UI

**Recurrence UI** is a plug-and-play UI component library for Ruby on Rails that makes it easy to create, edit, and display human-readable recurrence rules for recurring events.

Built on top of [ice_cube](https://github.com/ice-cube-ruby/ice_cube), it provides reusable UI components powered by [ViewComponent](https://viewcomponent.org/) and styled with Tailwind CSS.

[![Gem Version](https://img.shields.io/gem/v/recurrence_ui.svg)](https://rubygems.org/gems/recurrence_ui)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

## Features

- **Form integration:** Ready-to-use components for adding recurrence rule editors to model creation and editing forms.
- **Human-readable descriptions:** Converts `ice_cube` recurrence rules into readable descriptions.
- **Built-in internationalization:** Supports English (`en`), Russian (`ru`), Japanese (`ja`), Belarusian (`be`), and Ukrainian (`uk`).
- **Extensible translations:** Add new locales using standard YAML translation files and configuration.
- **Flexible time zones and week starts:** Configure time zones and the first day of the week. Values can be supplied through URL parameters, session data, user preferences, or application settings, depending on your integration.
- **Customizable styles:** Adjust the color palette using CSS custom properties (design tokens).
- **Light and dark themes:** Customize the appearance to match your application.
- **Flexible model attribute mapping:** Use custom database column names for recurrence rules, time zones, durations, and event start and end times.

## Requirements

Recurrence UI depends on the following components:

- **Ruby on Rails** >= 8.0
- **[ice_cube](https://github.com/ice-cube-ruby/ice_cube)** ~> 0.16 — recurrence rule management.
- **[ViewComponent](https://viewcomponent.org/)** >= 2.0 — reusable, encapsulated UI components.
- **Tailwind CSS ** >= 4.0 — styling, integrated through `tailwindcss-rails` or your host application's Tailwind CSS setup.

## Installation and configuration

Add the gem to your application's `Gemfile`:

```ruby
gem "recurrence_ui"
```

Then install the dependencies:

```bash
bundle install
```
### Automatic Installation

Run the installation generator to automatically create the initializer configuration and wire up the JavaScript components:
```bash
bin/rails g recurrence_ui:install
```
### Manual Setup (Alternative)

If you prefer to configure the gem manually:
1. Create an initializer at config/initializers/recurrence_ui.rb:
```ruby
require "recurrence_ui"
RecurrenceUi.configure do |config|
  # default locale, time_zone and week_start for all RecurrencePickerComponents in app
  # Could be redefined in RecurrencePickerComponent
  config.locale = :en
  config.time_zone = "UTC"
  config.week_start = 1
  config.start_time = "06:00" # Default start time for events (if no start_time is passed to the component or column does not configured in model)
  config.end_time = "16:00" # Default end time for events (if no end_time is passed to the component or column does not configured in model)
  config.duration = 3600 # Default duration in seconds for events (if no duration is passed to the component or column does not configured in model)
 
  #---- This is default UI options for all RecurrencePickerComponents in app that could be redefined in RecurrencePickerComponent --- #
  config.enabled_rule_types = %w[
     never
     daily
     weekly
     monthly_by_day_of_month
     monthly_by_weekday
     yearly_by_day_of_month
     yearly_by_weekday
   ]
  config.allow_multiple_rules = true     # Show only one rule(false) or multyple rules (true)
  config.show_duration = true            # Show/Hide duration fields in form
  config.show_start_date_time = true     # Show/Hide start date and time fields in form
  config.show_time_zone = true           # Show/Hide time zone in form
  config.show_end_date_time = false      # Show/Hide end date and time fields in form
  config.show_exceptions = true          # Show/Hide exceptions fields in form
  config.show_rdates = true              # Show/Hide additional dates fields in form
  config.show_termination = true         # Show/Hide termination fields in form
end
```
Available settings:

- locale — the default interface locale, such as :en, :ru, :uk, :be, or :ja.
- week_start — the first day of the week: 0 for Sunday or 1 for Monday.
- time_zone — if record dosen't have this field uses: ActiveSupport::TimeZone[zone_name] || Time.zone || ActiveSupport::TimeZone[Rails.application.config.time_zone]
- start_time — if record dosen't have this field uses DEFAULT_START_TIME = '09:00'.freeze from gem configuration.
- duration — if record dosen't have this field uses DEFAULT_DURATION = 0  from gem configuration. 
- end_time — if record dosen't have this field uses    DEFAULT_END_TIME = '17:00'.freeze
- allow_multiple_rules — show only one rule (false) or multiple rules (true).
- show_duration — show/hide duration fields in the form.
- show_start_date_time — show/hide start date and time fields in the form.
- show_time_zone — show/hide time zone in the form.
- show_end_date_time — show/hide end date and time fields in the form.
- show_exceptions — show/hide exceptions fields in the form.
- show_rdates — show/hide additional dates fields in the form.
- show_termination — show/hide termination fields in the form.


2. Import JavaScript: Add the following import to your application's main JavaScript file (app/javascript/application.js):
```javascript
import "recurrence_ui"
```
3. Import styles: For Tailwind CSS v4, add the style imports to your stylesheet (e.g., app/assets/stylesheets/application.tailwind.css):

```css
@import "tailwindcss";
@import "recurrence_ui/application.css";
```

Make sure the stylesheet is included in your application's asset pipeline and that your Tailwind CSS setup is compatible with the gem's styles.


### Model Integration

Include `RecurrenceUi::HasRecurrence` in your model and configure the mapping between the gem's attributes and your database columns.
If you dont configure some fields for your model, they will not connect to your base.
But some of them could uses default value if not configured. Could be redefined for all app in config/initializers/recurrence_ui.rb such as time_zone, start_time, duration and end_time.

For example:

```ruby
class Event < ApplicationRecord
  include RecurrenceUi::HasRecurrence

  has_recurrence rules:      :recurring_rules, #  This column is needed for gem,
                 start_time: :start_at,        #  others - optional. Format:
                 end_time:   :end_at,          #  name_in_gem: :name_in_your_db_schema 
                 time_zone:  :time_zone,       # for default values see Configuration
                 duration:   :duration
end
```

You can configure different attribute names for different models:

```ruby
class Task < ApplicationRecord
  include RecurrenceUi::HasRecurrence

  has_recurrence rules:      :recurrence_data,
                 start_time: :due_date
end
```

Use the attribute names that match your application's database schema and the attributes supported by your model integration.

Add required params to controller of your Model.
```erb
def event_params
      params.require(:event).permit(
         #other params of your model
         *Event.recurrence_permitted_params # add this with name of your Model 
         )
    end
```


### View Integration

Render the recurrence editor inside a Rails form using `RecurrenceUi::RecurrencePickerComponent`:

```erb
<%= form_with model: @event do |form| %>
<%= render RecurrenceUi::RecurrencePickerComponent.new(
      form: form,
      record: @event, 
      allow_multiple_rules: true,
      show_duration: true,
      show_start_date_time: true,
      show_time_zone: true,
      show_end_date_time: true,
      show_exceptions: true,
      show_rdates: true,
      show_termination: true,
      locale: params[:locale],
      time_zone: params[:time_zone],
      week_start: params[:week_start]
      )
    %>

  <%= form.submit "Save" %>
<% end %>
```

The `locale`, `time_zone`, and `week_start` options can be supplied dynamically when needed. If omitted, the component can use the applicable defaults provided by your integration.

## Internationalization

Recurrence UI currently supports the following locales:

- English (`en`)
- Russian (`ru`)
- Ukrainian (`uk`)
- Belarusian (`be`)
- Japanese (`ja`)

### Adding a new locale

You can extend the interface with additional translations.

For example, to add German (`de`):

1. Create a translation file named `config/locales/recurrence_ui.de.yml` in your application.
2. Add the required translation keys, including the relevant labels, actions, duration descriptions, and other interface strings.
3. Configure the new locale or pass it dynamically through your application's request parameters.

Make sure the translation file follows the structure expected by the gem's existing locale files.

## Themes and Customization

Recurrence UI uses CSS custom properties (design tokens) to control its color palette.

You can override these properties in your application's stylesheet to match your brand or customize the appearance of the interface.

For example:

```css
:root {
  --rui-primary-bg: #2563eb;
}

/* Dark theme */
.dark,
[data-rui-theme="dark"] {
  --rui-bg-main: #1f2937;
  --rui-text-main: #f9fafb;
}
```

Use the CSS variables supported by the gem to customize the interface. The example above illustrates the approach; available tokens and theme selectors depend on the styles provided by your version of Recurrence UI.

## Example Application

If you want to see `recurrence_ui` in action, check out the [rails-recurrence-ui-dummy](https://github.com/assoly/rails-recurrence-ui-dummy) repository. It demonstrates a fully configured Ruby on Rails application featuring:
- Database models with `HasRecurrence` integration.
- Form views using `ViewComponent` and Tailwind CSS.
- Initializer and internationalization (i18n) setup.

## Contributing

Contributions, bug reports, and feature requests are welcome!

To get started:

1. Clone the repository.
2. Install the dependencies:

   ```bash
   bundle install
   ```

3. Run the test suite:

   ```bash
   bundle exec rake test
   ```

4. Create a branch, make your changes, and open a pull request.

Please make sure your changes are covered by tests where appropriate.

## Testing

*Note: The test suite is currently under active development. Contributions are very welcome!*

### Planned Test Suite

- [ ] **Models & Concerns (`HasRecurrence`):** Test attribute mapping, JSON parsing, virtual form attributes, and `IceCube::Schedule` generation.
- [ ] **Formatter Service (`RecurrenceFormatterService`):** Validate human-readable summaries, smart date/time deduplication, and month declensions.
- [ ] **Internationalization (I18n):** Automated checks to ensure all locales (`en`, `ru`, `uk`, `be`, `ja`) share a consistent translation key structure.
- [ ] **ViewComponents:** Test proper rendering and Stimulus data-attribute bindings for form components.

## 📄 License

Recurrence UI is available under the [MIT License](https://opensource.org/licenses/MIT).
