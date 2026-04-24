module SpreeBoxnow
  class CancelVoucher
    attr_reader :shipment

    def initialize(shipment)
      @shipment = shipment
    end

    def call
      parcel_id = shipment.tracking
      raise VoucherError, 'No BoxNow parcel ID on this shipment' if parcel_id.blank?

      Boxnow::ApiClient.new.cancel_parcel(parcel_id)

      shipment.tracking = nil
      shipment.private_metadata.delete('boxnow.vg_child')
      shipment.private_metadata.delete('boxnow.destination_location_id')
      shipment.save!
    rescue Boxnow::ApiClient::ApiError => e
      raise VoucherError, e.message
    end

    class VoucherError < StandardError; end
  end
end
