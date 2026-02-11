module Spree
  module OrderDecorator
    def can_create_boxnow_voucher?
      shipments.any?(&:can_create_boxnow_voucher?)
    end

    def can_print_boxnow_voucher?
      shipments.any?(&:can_print_boxnow_voucher?)
    end
  end
end

Spree::Order.prepend Spree::OrderDecorator
