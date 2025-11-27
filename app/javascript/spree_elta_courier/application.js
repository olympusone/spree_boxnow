import '@hotwired/turbo-rails'
import { Application } from '@hotwired/stimulus'

let application

if (typeof window.Stimulus === "undefined") {
  application = Application.start()
  application.debug = false
  window.Stimulus = application
} else {
  application = window.Stimulus
}

import EltaCourierController from 'spree_boxnow/controllers/boxnow_controller'

application.register('boxnow', EltaCourierController)
