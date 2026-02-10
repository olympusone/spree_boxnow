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

import SpreeBoxnowController from 'spree_boxnow/controllers/spree_boxnow_controller'

application.register('spree-boxnow', SpreeBoxnowController)
