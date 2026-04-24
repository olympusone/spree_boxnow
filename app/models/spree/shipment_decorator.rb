module Spree
  module ShipmentDecorator
    def can_create_boxnow_voucher?
      !tracked? && ready? && shipping_method.boxnow?
    end

    def can_print_boxnow_voucher?
      tracked? && shipping_method.boxnow?
    end

    def can_cancel_boxnow_voucher?
      tracked? && shipping_method&.boxnow? && !shipped?
    end
  end
end

Spree::Shipment.prepend Spree::ShipmentDecorator
