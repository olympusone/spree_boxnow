require 'faraday'
require 'faraday/retry'

module SpreeBoxnow
  class ApiClient
    include Spree::IntegrationsConcern

    TOKEN_MARGIN = 60 # seconds before expiry to refresh

    def initialize
      integration = store_integration('boxnow')
      raise 'BoxNow integration not configured' unless integration

      @client_id     = integration.preferred_client_id
      @client_secret = integration.preferred_client_secret
      @api_url       = integration.preferred_api_url.to_s.chomp('/')
    end

    def create_delivery_request(params)
      post('/api/v1/delivery-requests', params)
    end

    def fetch_label(parcel_id, format: 'pdf')
      get("/api/v1/parcels/#{parcel_id}/label.#{format}", raw: true)
    end

    def cancel_parcel(parcel_id)
      post("/api/v1/parcels/#{parcel_id}:cancel", {})
    end

    def destinations(params = {})
      get('/api/v1/destinations', params: params)
    end

    private

    def token_cache_key
      "spree_boxnow/access_token/#{@client_id}"
    end

    def access_token
      cached = Rails.cache.read(token_cache_key)
      return cached if cached

      response = Faraday.post(
        "#{@api_url}/api/v1/auth-sessions",
        { grant_type: 'client_credentials', client_id: @client_id, client_secret: @client_secret }.to_json,
        'Content-Type' => 'application/json',
        'Accept'       => 'application/json'
      )

      raise ApiError, "Authentication failed (#{response.status}): #{response.body}" unless response.success?

      body       = JSON.parse(response.body)
      token      = body['access_token']
      expires_in = body['expires_in'].to_i - TOKEN_MARGIN

      Rails.cache.write(token_cache_key, token, expires_in: expires_in)
      token
    end

    def json_connection
      @json_connection ||= Faraday.new(url: @api_url) do |f|
        f.request  :json
        f.response :json
        f.request  :retry, max: 2, interval: 0.5
        f.adapter  Faraday.default_adapter
      end
    end

    def raw_connection
      @raw_connection ||= Faraday.new(url: @api_url) do |f|
        f.request  :retry, max: 2, interval: 0.5
        f.adapter  Faraday.default_adapter
      end
    end

    def get(path, params: {}, raw: false)
      conn = raw ? raw_connection : json_connection
      response = conn.get(path) do |req|
        req.headers['Authorization'] = "Bearer #{access_token}"
        req.headers['Accept']        = raw ? 'application/pdf' : 'application/json'
        req.params.merge!(params) unless params.empty?
      end
      handle_response(response, raw: raw)
    end

    def post(path, body)
      response = json_connection.post(path) do |req|
        req.headers['Authorization'] = "Bearer #{access_token}"
        req.body = body
      end
      handle_response(response)
    end

    def handle_response(response, raw: false)
      unless response.success?
        code = response.body.is_a?(Hash) ? response.body['code'] : nil
        message = code ? I18n.t("spree.boxnow.api_errors.#{code}", default: response.body.to_s) : response.body.to_s
        raise ApiError, "[#{code || response.status}] #{message}"
      end

      raw ? response.body : response.body
    end

    class ApiError < StandardError; end
  end
end
