module SpreeBoxnow
  class PrintVouchers
    attr_reader :parcel_id

    def initialize(parcel_id)
      @parcel_id = parcel_id
    end

    def call
      SpreeBoxnow::ApiClient.new.fetch_label(parcel_id, format: 'pdf')
    rescue SpreeBoxnow::ApiClient::ApiError => e
      raise VoucherError, e.message
    end

    class VoucherError < StandardError; end
  end
end
