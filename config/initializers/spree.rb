Rails.application.config.after_initialize do
  Spree.integrations << Spree::Integrations::Boxnow

  # Admin partials
  Spree.admin.partials.head << 'spree_boxnow/head'
  Spree.admin.partials.order_page_dropdown << 'spree_boxnow/order_dropdown_options'
end
