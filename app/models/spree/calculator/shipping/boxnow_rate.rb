module Spree
  module Calculator::Shipping
    class BoxnowRate < Spree::ShippingCalculator
      # Hard limits (BoxNow)
      MAX_WEIGHT_KG  = 20.0
      MAX_HEIGHT_CM  = 36.0
      MAX_WIDTH_CM   = 45.0
      MAX_DEPTH_CM   = 60.0

      # Size thresholds (height decides the size; width/depth are constant limits)
      SIZE_MAX_HEIGHT_CM = {
        small:  8.0,
        medium: 17.0,
        large:  36.0
      }.freeze

      preference :small_box_price,  :decimal, default: 0.0
      preference :medium_box_price, :decimal, default: 0.0
      preference :large_box_price,  :decimal, default: 0.0

      preference :base_padding_cm,    :decimal, default: 1.0
      preference :multi_item_factor,  :decimal, default: 1.05

      validates :preferred_small_box_price,
                :preferred_medium_box_price,
                :preferred_large_box_price,
                :preferred_base_padding_cm,
                :preferred_multi_item_factor,
                presence: true

      def self.description
        Spree.t(:shipping_boxnow_rate)
      end

      def compute_package(package)
        return nil if package.weight.to_f > MAX_WEIGHT_KG

        dims = estimated_parcel_dimensions_cm(package)
        return nil if dims.nil?

        dims = apply_packing_margin(dims, package)

        # allow rotation by sorting dims (smallest->height threshold)
        s, m, d = [dims[:height], dims[:width], dims[:depth]].map(&:to_f).sort
        return nil if s > MAX_HEIGHT_CM || m > MAX_WIDTH_CM || d > MAX_DEPTH_CM

        size = box_size_for_height(s)
        return nil unless size

        price_for(size)
      end

      private

      # Conservative 1-parcel estimate:
      # - For each item: sort dims s<=m<=d
      # - Stack along smallest side (s) across quantities => parcel height
      # - Width = max(m), Depth = max(d) across all items
      def estimated_parcel_dimensions_cm(package)
        heights = []
        widths  = []
        depths  = []

        package.contents.each do |content|
          variant = content.variant
          qty = content.quantity

          dims = variant_dimensions_cm(variant)
          return nil if dims.nil?

          s, m, d = dims.sort
          heights << (s * qty)
          widths  << m
          depths  << d
        end

        {
          height: heights.sum,
          width:  widths.max || 0.0,
          depth:  depths.max || 0.0
        }
      end

      def apply_packing_margin(dims, package)
        factor = multi_item?(package) ? preferred_multi_item_factor : 1.0

        {
          height: (dims[:height].to_f * factor) + preferred_base_padding_cm,
          width:  (dims[:width].to_f  * factor) + preferred_base_padding_cm,
          depth:  (dims[:depth].to_f  * factor) + preferred_base_padding_cm
        }
      end

      def multi_item?(package)
        package.contents.sum { |c| c.quantity } > 1
      end

      def variant_dimensions_cm(variant)
        height = variant.height.to_f
        width  = variant.width.to_f
        depth  = variant.depth.to_f

        return nil if [height, width, depth].any? { |v| v <= 0 }

        [height, width, depth]
      end

      def box_size_for_height(height_cm)
        return :small  if height_cm <= SIZE_MAX_HEIGHT_CM[:small]
        return :medium if height_cm <= SIZE_MAX_HEIGHT_CM[:medium]
        return :large  if height_cm <= SIZE_MAX_HEIGHT_CM[:large]
      end

      def price_for(size)
        case size
        when :small  then preferred_small_box_price
        when :medium then preferred_medium_box_price
        when :large  then preferred_large_box_price
        end
      end
    end
  end
end
