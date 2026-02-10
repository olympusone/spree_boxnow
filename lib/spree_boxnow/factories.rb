FactoryBot.define do
  factory :boxnow_integration, class: Spree::Integrations::Boxnow do
    active { true }
    preferred_client_id { ENV['BOXNOW_CLIENT_ID'] }
    preferred_client_secret { ENV['BOXNOW_CLIENT_SECRET'] }
    preferred_partner_id { ENV['BOXNOW_PARTNER_ID'] }
    preferred_api_url { ENV['BOXNOW_API_URL'] }
    store { Spree::Store.default }
  end
end
