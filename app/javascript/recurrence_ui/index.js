import RecurrenceUiController from "./recurrence_ui_controller"

export function registerRecurrenceUiController(application) {
  if (application) {
    application.register("recurrence-ui", RecurrenceUiController)
  }
}

// Automatically register the controller if Stimulus is already initialized
if (typeof window !== "undefined") {
  if (window.Stimulus) {
    window.Stimulus.register("recurrence-ui", RecurrenceUiController)
  } else {
    document.addEventListener("DOMContentLoaded", () => {
      if (window.Stimulus) {
        window.Stimulus.register("recurrence-ui", RecurrenceUiController)
      }
    })
  }
}

export { RecurrenceUiController }