pin 'application-spree-boxnow', to: 'spree_boxnow/application.js', preload: false

pin_all_from SpreeBoxnow::Engine.root.join('app/javascript/spree_boxnow/controllers'),
             under: 'spree_boxnow/controllers',
             to:    'spree_boxnow/controllers',
             preload: 'application-spree-boxnow'
