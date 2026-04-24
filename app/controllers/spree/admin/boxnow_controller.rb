require 'combine_pdf'

module Spree
  module Admin
    class BoxnowController < Spree::Admin::BaseController
      include Spree::Admin::OrdersFiltersHelper

      def create
        begin
          load_order

          @order.shipments.each do |shipment|
            next unless shipment.can_create_boxnow_voucher?

            result = SpreeBoxnow::CreateVoucher.new(shipment).call

            shipment.tracking = result[:parcel_id]
            shipment.private_metadata['boxnow.vg_child'] = result[:child_parcel_ids]
            shipment.save!
          end

          flash[:success] = Spree.t('admin.integrations.boxnow.voucher_successfully_created')
        rescue ActiveRecord::RecordNotFound
          order_not_found
        rescue StandardError => e
          Rails.logger.error "Boxnow Error: #{e.message}"

          flash[:error] = "#{Spree.t('admin.integrations.boxnow.voucher_creation_failed')}: #{e.message}"
        end
      end

      def print
        begin
          load_order

          shipments = @order.shipments.select(&:can_print_boxnow_voucher?)

          voucher_numbers = shipments.flat_map do |shipment|
            child_ids = shipment.private_metadata['boxnow.vg_child'] || []
            [shipment.tracking] + child_ids
          end

          if voucher_numbers.empty?
            raise StandardError, Spree.t('admin.integrations.boxnow.voucher_print_failed')
          end

          pdf_contents = voucher_numbers.map do |parcel_id|
            SpreeBoxnow::PrintVouchers.new(parcel_id).call
          end

          merged_bytes =
            if pdf_contents.size == 1
              pdf_contents.first
            else
              combined = CombinePDF.new
              pdf_contents.each { |bytes| combined << CombinePDF.parse(bytes) }
              combined.to_pdf
            end

          send_data merged_bytes,
            filename: "#{@order.number}.pdf",
            type: 'application/pdf',
            disposition: 'inline'
        rescue ActiveRecord::RecordNotFound
          render json: {
            error: flash_message_for(Spree::Order.new, :not_found)
          }, status: 404
        rescue StandardError => e
          Rails.logger.error "Boxnow Error: #{e.message}"

          render json: {
            error: Spree.t('admin.integrations.boxnow.voucher_print_failed')
          }, status: 400
        end
      end

      def cancel
        load_order

        @order.shipments.each do |shipment|
          next unless shipment.can_cancel_boxnow_voucher?

          SpreeBoxnow::CancelVoucher.new(shipment).call
        end

        flash[:success] = Spree.t('admin.integrations.boxnow.voucher_successfully_cancelled')
      rescue ActiveRecord::RecordNotFound
        order_not_found
      rescue StandardError => e
        Rails.logger.error "Boxnow Error: #{e.message}"

        flash[:error] = "#{Spree.t('admin.integrations.boxnow.voucher_cancellation_failed')}: #{e.message}"
      end

      def select_locker
        load_order
        shipment = @order.shipments.find { |s| s.shipping_method&.boxnow? }

        if shipment.nil? || params[:locker_id].blank?
          render json: { error: 'Invalid request' }, status: :unprocessable_entity and return
        end

        shipment.private_metadata['boxnow.destination_location_id'] = params[:locker_id]
        shipment.private_metadata['boxnow.locker_name']             = params[:locker_name]
        shipment.private_metadata['boxnow.locker_address']          = params[:locker_address]
        shipment.save!

        render json: { success: true }
      rescue ActiveRecord::RecordNotFound
        order_not_found
      end

      private

      def load_order
        @order = current_store.orders.find(params[:order_id])
        authorize! action, @order
        @order
      end

      def order_not_found
        flash[:error] = flash_message_for(Spree::Order.new, :not_found)
      end
    end
  end
end
