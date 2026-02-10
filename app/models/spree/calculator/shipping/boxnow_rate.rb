module Spree
  module Calculator::Shipping
    class BoxnowRate < Spree::ShippingCalculator
      preference :small_box_price, :decimal, default: 0.0
      preference :medium_box_price, :decimal, default: 0.0
      preference :large_box_price, :decimal, default: 0.0

      validates :preferred_small_box_price, presence: true
      validates :preferred_medium_box_price, presence: true
      validates :preferred_large_box_price, presence: true

      def self.description
        Spree.t(:shipping_boxnow_rate)
      end

      def compute_package(package)
        # TODO: Implement the logic to calculate the shipping cost based on the package contents and the box sizes
      end
    end
  end
end
