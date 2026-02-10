module Spree
  module Integrations
    class Boxnow < Spree::Integration
      preference :client_id, :string
      preference :client_secret, :string
      preference :partner_id, :string
      preference :api_url, :string

      validates :preferred_client_id, presence: true
      validates :preferred_client_secret, presence: true
      validates :preferred_partner_id, presence: true
      validates :preferred_api_url, presence: true

      def self.integration_group
        'shipping'
      end

      def self.icon_path
        'integration_icons/boxnow-logo.png'
      end
    end
  end
end
