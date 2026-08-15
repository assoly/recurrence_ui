RecurrenceUi::Engine.routes.draw do
    if Rails.env.development?
        get '/dev/recurrence_previews', to: 'dev/recurrence_previews#index'
    end
end
