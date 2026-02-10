Rails.application.config.after_initialize do
  Spree.integrations << Spree::Integrations::Boxnow

  Rails.application.config.spree.calculators.shipping_methods << Spree::Calculator::Shipping::BoxnowRate

  # Admin partials
  Spree.admin.partials.head << 'spree_boxnow/head'
  Spree.admin.partials.order_page_dropdown << 'spree_boxnow/order_dropdown_options'
  Spree.admin.partials.shipping_method_form << 'spree/admin/shipping_methods/boxnow_form'

  Spree::PermittedAttributes.shipping_method_attributes << :boxnow
end
