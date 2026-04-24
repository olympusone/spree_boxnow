module SpreeBoxnow
  class CancelVoucher
    attr_reader :shipment

    def initialize(shipment)
      @shipment = shipment
    end

    def call
      parcel_id = shipment.tracking
      raise VoucherError, 'No BoxNow parcel ID on this shipment' if parcel_id.blank?

      SpreeBoxnow::ApiClient.new.cancel_parcel(parcel_id)

      shipment.tracking = nil
      shipment.private_metadata.delete('boxnow.vg_child')
      shipment.save!
    rescue SpreeBoxnow::ApiClient::ApiError => e
      raise VoucherError, e.message
    end

    class VoucherError < StandardError; end
  end
end
