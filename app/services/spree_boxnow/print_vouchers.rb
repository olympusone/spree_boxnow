module SpreeBoxnow
  class PrintVouchers
    attr_reader :parcel_id

    def initialize(parcel_id)
      @parcel_id = parcel_id
    end

    def call
      Boxnow::ApiClient.new.fetch_label(parcel_id, format: 'pdf')
    rescue Boxnow::ApiClient::ApiError => e
      raise VoucherError, e.message
    end

    class VoucherError < StandardError; end
  end
end
