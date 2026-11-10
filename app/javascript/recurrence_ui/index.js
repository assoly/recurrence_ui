import RecurrenceUiController from "./recurrence_ui_controller"

export function registerRecurrenceUiController(application) {
  if (application) {
    application.register("recurrence-ui", RecurrenceUiController)
  }
}

export { RecurrenceUiController }