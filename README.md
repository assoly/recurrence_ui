# Recurrence UI

**Recurrence UI** is a plug-and-play UI component library for Ruby on Rails that makes it easy to create, edit, and display human-readable recurrence rules for recurring events.

Built on top of [ice_cube](https://github.com/ice-cube-ruby/ice_cube), it provides reusable UI components powered by [ViewComponent](https://viewcomponent.org/) and styled with Tailwind CSS.

[![Gem Version](https://img.shields.io/gem/v/recurrence_ui.svg)](https://rubygems.org/gems/recurrence_ui)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

## Features

- **Form integration:** Ready-to-use components for adding recurrence rule editors to model creation and editing forms.
- **Human-readable descriptions:** Converts `ice_cube` recurrence rules into readable descriptions.
- **Built-in internationalization:** Supports English (`en`), Russian (`ru`), Japanese (`ja`), Belarusian (`be`), and Ukrainian (`uk`).
- **Extensible translations:** Add new locales using standard YAML translation files.
- **Flexible time zones and week starts:** Configure time zones and the first day of the week.
- **Customizable styles:** Adjust the color palette using CSS custom properties (design tokens).
- **Light and dark themes:** Customize the appearance to match your application.
- **Flexible model attribute mapping:** Use custom database column names for recurrence rules, time zones, durations, and event start and end times.

## Requirements

Recurrence UI depends on the following components:

- **Ruby on Rails** >= 8.0
- **[ice_cube](https://github.com/ice-cube-ruby/ice_cube)** ~> 0.16
- **[ViewComponent](https://viewcomponent.org/)** >= 2.0
- **Tailwind CSS** >= 4.0

Tailwind CSS can be integrated through `tailwindcss-rails` or your host application's existing Tailwind CSS setup.

## Installation and Configuration

### 1. Add the gem

Add Recurrence UI to your application's `Gemfile`:

```ruby
gem "recurrence_ui"
```

Install the dependencies:

```bash
bundle install
```

### 2. Automatic Installation (Recommended)

Run the installation generator:

```bash
bin/rails g recurrence_ui:install
```

The generator configures the necessary integration with your Rails application:

- Registers the Recurrence UI Stimulus controller in your application's Stimulus application.
- Adds the Recurrence UI stylesheet to your application's stylesheets.
- Creates the configuration initializer with default settings, if applicable.

The gem's Engine automatically makes its JavaScript, CSS assets, and translations available to the host application.

No additional Importmap configuration or manual locale loading is required.

### 3. Manual Installation (Alternative)

If you prefer to configure the integration yourself, follow these steps.

**Step 1. Create an initializer**

Create `config/initializers/recurrence_ui.rb`:

```ruby
RecurrenceUi.configure do |config|
  # General settings
  config.locale = :en
  config.time_zone = "UTC"
  config.week_start = 1

  # Default event values
  config.start_time = "09:00"
  config.end_time = "17:00"
  config.duration = 0

  # UI options
  config.enabled_rule_types = %w[
    never
    daily
    weekly
    monthly_by_day_of_month
    monthly_by_weekday
    yearly_by_day_of_month
    yearly_by_weekday
  ]

  config.allow_multiple_rules = true

  config.show_duration = true
  config.show_start_date_time = true
  config.show_time_zone = true
  config.show_end_date_time = false
  config.show_exceptions = true
  config.show_rdates = true
  config.show_termination = true
end
```

**Step 2. Register the Stimulus controller**

Register the Recurrence UI controller in your application's Stimulus setup.

For example, in `app/javascript/controllers/index.js`:

```javascript
import RecurrenceUiController from "recurrence_ui"

application.register("recurrence-ui", RecurrenceUiController)
```

Use the controller's actual import path and identifier provided by the gem.

**Step 3. Import the stylesheet**

For Tailwind CSS v4, add the following imports to your application's stylesheet, for example `app/assets/stylesheets/application.tailwind.css`:

```css
@import "tailwindcss";
@import "recurrence_ui/application.css";
```

Make sure the stylesheet is included in your application's asset pipeline.

**Note:** Importmap paths, JavaScript assets, and locale files are provided by the gem's Engine. You do not need to configure them manually.

## Configuration

Recurrence UI can be configured globally through `config/initializers/recurrence_ui.rb`.

The following settings are available:

### General settings

| Setting | Description |
|---|---|
| `locale` | Default interface locale (`:en`, `:ru`, `:uk`, `:be`, `:ja`). |
| `time_zone` | Default time zone. |
| `week_start` | First day of the week: `0` for Sunday or `1` for Monday. |
| `start_time` | Default event start time. |
| `end_time` | Default event end time. |
| `duration` | Default event duration in seconds. |

### UI settings

| Setting | Description |
|---|---|
| `enabled_rule_types` | Recurrence rule types available in the editor. |
| `allow_multiple_rules` | Allows multiple recurrence rules when `true`. |
| `show_duration` | Shows or hides duration fields. |
| `show_start_date_time` | Shows or hides start date and time fields. |
| `show_time_zone` | Shows or hides the time zone field. |
| `show_end_date_time` | Shows or hides end date and time fields. |
| `show_exceptions` | Shows or hides exception dates. |
| `show_rdates` | Shows or hides additional recurrence dates. |
| `show_termination` | Shows or hides recurrence termination settings. |

Component-level options can override the global configuration where supported.

## Model Integration

Include `RecurrenceUi::HasRecurrence` in your model and configure the mapping between the gem's attributes and your database columns.

The recurrence rules attribute is required. Other attributes are optional and can be configured according to your application's database schema.

For example:

```ruby
class Event < ApplicationRecord
  include RecurrenceUi::HasRecurrence

  has_recurrence rules:      :recurring_rules,
                 start_time: :start_at,
                 end_time:   :end_at,
                 time_zone:  :time_zone,
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

The mapping format is:

```ruby
gem_attribute: :database_column
```

If an optional attribute is not configured, the gem can use its applicable default value where supported.

### Strong Parameters

Add the recurrence parameters to your controller's permitted parameters:

```ruby
def event_params
  params.require(:event).permit(
    # Other model parameters
    *Event.recurrence_permitted_params
  )
end
```

## View Integration

Render the recurrence editor inside a Rails form using `RecurrenceUi::RecurrencePickerComponent`:

```erb
<%= form_with model: @event do |form| %>
  <%= render RecurrenceUi::RecurrencePickerComponent.new(
    form: form,
    record: @event,
    locale: params[:locale],
    time_zone: params[:time_zone],
    week_start: params[:week_start]
  ) %>

  <%= form.submit "Save" %>
<% end %>
```

The component uses the application's global configuration by default.

You can also override supported component options when rendering it.

## Internationalization

Recurrence UI currently supports:

- English (`en`)
- Russian (`ru`)
- Ukrainian (`uk`)
- Belarusian (`be`)
- Japanese (`ja`)

### Adding a new locale

You can extend the interface with additional translations.

For example, to add German (`de`):

1. Create a translation file named `config/locales/recurrence_ui.de.yml` in your application.
2. Add the required translation keys, following the structure of the gem's existing locale files.
3. Use the new locale through your application's I18n configuration or pass it to the component.

The gem's Engine makes its built-in translations available automatically.

## Themes and Customization

Recurrence UI uses CSS custom properties (design tokens) to control its color palette.

You can override these properties in your application's stylesheet:

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

Use the CSS variables supported by the gem to customize its appearance.

## Example Application

To see Recurrence UI in action, check out the [rails-recurrence-ui-dummy](https://github.com/assoly/rails-recurrence-ui-dummy) repository.

It demonstrates a fully configured Ruby on Rails application featuring:

- Database models with `HasRecurrence` integration.
- Form views using ViewComponent and Tailwind CSS.
- Initializer and internationalization setup.

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

The test suite is currently under active development. Contributions are very welcome!

### Planned Test Suite

- [ ] **Models & Concerns (`HasRecurrence`):** Test attribute mapping, JSON parsing, virtual form attributes, and `IceCube::Schedule` generation.
- [ ] **Formatter Service:** Validate human-readable summaries, smart date/time deduplication, and month declensions.
- [ ] **Internationalization (I18n):** Automated checks to ensure all locales share a consistent translation key structure.
- [ ] **ViewComponents:** Test proper rendering and Stimulus data-attribute bindings.

## License

Recurrence UI is available under the [MIT License](https://opensource.org/licenses/MIT).