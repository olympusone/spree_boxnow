module SpreeBoxnow
  class CreateVoucher
    include Spree::IntegrationsConcern

    attr_reader :shipment, :order

    def initialize(shipment)
      @shipment = shipment
      @order    = shipment.order
    end

    def call
      integration = store_integration('boxnow')
      raise VoucherError, 'BoxNow integration not configured' unless integration

      destination_id = shipment.private_metadata['boxnow.destination_location_id']
      raise VoucherError, 'No BoxNow locker selected for this shipment' if destination_id.blank?

      address = shipment.address || order.ship_address
      cod     = order.payment_method&.cod_payment?

      params = {
        orderNumber:         shipment.number,
        invoiceValue:        order.total.to_s,
        paymentMode:         cod ? 'cod' : 'prepaid',
        amountToBeCollected: cod ? shipment.final_price_with_items.to_f.to_s : '0.00',
        origin: {
          locationId:    integration.preferred_origin_location_id,
          contactName:   integration.preferred_contact_name.presence || '',
          contactNumber: integration.preferred_contact_phone.presence || '',
          contactEmail:  integration.preferred_contact_email.presence || ''
        },
        destination: {
          locationId:    destination_id,
          contactName:   address.full_name,
          contactNumber: address.phone.to_s,
          contactEmail:  order.email.to_s
        },
        items: [{
          id:              '1',
          name:            'voucher',
          value:           '0.00',
          compartmentSize: parcel_size,
          weight:          shipment.item_weight.to_f.round
        }]
      }

      result = SpreeBoxnow::ApiClient.new.create_delivery_request(params)

      parcels = result['parcels'] || []
      raise VoucherError, 'BoxNow returned no parcels' if parcels.empty?

      {
        parcel_id:        parcels[0]['id'],
        child_parcel_ids: parcels[1..].map { |p| p['id'] }
      }
    rescue SpreeBoxnow::ApiClient::ApiError => e
      raise VoucherError, e.message
    end

    private

    # Returns BoxNow compartment size: 1=small, 2=medium, 3=large
    # Mirrors the height thresholds in BoxnowRate calculator
    def parcel_size
      height = shipment.manifest.sum { |item| item.variant.height.to_f * item.quantity }
      if    height <= 8.0  then 1
      elsif height <= 17.0 then 2
      else                      3
      end
    end

    class VoucherError < StandardError; end
  end
end
