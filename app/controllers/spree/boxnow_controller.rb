module Spree
  class BoxnowController < Spree::StoreController
    def select_locker
      order = current_order

      if order.blank? || params[:locker_id].blank?
        render json: { error: 'Invalid request' }, status: :unprocessable_entity
        return
      end

      order.shipments.each do |shipment|
        next unless shipment.shipping_method&.boxnow?
        next if shipment.tracked?

        shipment.private_metadata['boxnow.destination_location_id'] = params[:locker_id]
        shipment.private_metadata['boxnow.locker_name']             = params[:locker_name]
        shipment.private_metadata['boxnow.locker_address']          = params[:locker_address]
        shipment.save!
      end

      render json: { success: true }
    end
  end
end
