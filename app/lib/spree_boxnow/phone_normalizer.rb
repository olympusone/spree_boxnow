require 'phonelib'

module SpreeBoxnow
  # Normalizes phone numbers to the full international (E.164) format BoxNow
  # requires, e.g. +306912345678. `country_iso` is the ISO 3166-1 alpha-2
  # code used to interpret a number given in national format (defaults to
  # GR, since BoxNow only operates in Greece); numbers already given in
  # international format (leading +) are parsed as-is regardless.
  module PhoneNormalizer
    module_function

    def call(phone, country_iso = nil)
      return '' if phone.blank?

      parsed = Phonelib.parse(phone, country_iso || 'GR')
      parsed.valid? ? parsed.e164 : phone.to_s
    end
  end
end
