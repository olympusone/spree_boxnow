module Spree
  module Calculator::Shipping
    class BoxnowRate < Spree::ShippingCalculator
      # Hard limits (BoxNow)
      MAX_WEIGHT_KG  = 20.0
      MAX_HEIGHT_CM  = 36.0
      MAX_WIDTH_CM   = 45.0
      MAX_DEPTH_CM   = 60.0

      # Size thresholds — tier is determined by the smallest sorted dimension
      SIZE_MAX_HEIGHT_CM = {
        small:  8.0,
        medium: 17.0,
        large:  36.0
      }.freeze

      preference :small_box_price,  :decimal, default: 0.0
      preference :medium_box_price, :decimal, default: 0.0
      preference :large_box_price,  :decimal, default: 0.0

      preference :base_padding_cm,   :decimal, default: 1.0
      preference :multi_item_factor, :decimal, default: 1.05

      validates :preferred_small_box_price,
                :preferred_medium_box_price,
                :preferred_large_box_price,
                :preferred_base_padding_cm,
                :preferred_multi_item_factor,
                presence: true

      def self.description
        Spree.t(:shipping_boxnow_rate)
      end

      SIZES_ORDERED = %i[small medium large].freeze

      def compute_package(package)
        return nil if package.weight.to_f > MAX_WEIGHT_KG

        boxes = minimum_bounding_boxes(package)
        return nil if boxes.nil?

        best_size = nil

        boxes.each do |sml|
          padded = apply_packing_margin({ height: sml[0], width: sml[1], depth: sml[2] }, package)
          s, m, d = [padded[:height], padded[:width], padded[:depth]].map(&:to_f).sort
          next if s > MAX_HEIGHT_CM || m > MAX_WIDTH_CM || d > MAX_DEPTH_CM

          size = box_size_for_height(s)
          next unless size

          best_size = smaller_size(best_size, size)
        end

        return nil unless best_size

        price_for(best_size)
      end

      private

      # Exhaustive recursive bounding-box search over all item orientations and
      # all possible groupings (hierarchical binary splits).
      #
      # Each line item (distinct SKU) is treated as a block in one of up to 3
      # orientations — one per choice of which dimension is multiplied by qty.
      # The solver tries every binary partition of line items into two groups,
      # combines the Pareto-optimal bounding boxes of each group along 3 axes,
      # and Pareto-prunes the result. Memoisation by sorted index set ensures
      # each subset is computed exactly once.
      #
      # N = distinct line items (SKUs), not total quantity.
      # 100 identical keycards = 1 line item = N=1 → trivially fast.
      # For very large N (many distinct SKUs), a time-based execution guard
      # can be added if observed to be slow in production.
      def minimum_bounding_boxes(package)
        all_items = package.contents.map do |content|
          orientations = item_block_orientations(content.variant, content.quantity)
          return nil if orientations.nil?
          orientations
        end

        return all_items[0] if all_items.size == 1

        solve_boxes((0...all_items.size).to_a, all_items, {})
      end

      # Recursive memoised solver.
      # indices   — sorted Array<Integer> identifying this subset within all_items
      # all_items — Array<Array<[s,m,l]>>, per-item orientation sets
      # cache     — Hash keyed by sorted index array
      def solve_boxes(indices, all_items, cache)
        return cache[indices] if cache.key?(indices)

        result =
          if indices.size == 1
            all_items[indices[0]]
          else
            # Pin indices[0] in the left group and vary what else joins it.
            # This enumerates every unordered binary partition exactly once.
            rest     = indices[1..]
            combined = []

            0.upto(rest.size - 1) do |left_size|
              rest.combination(left_size).each do |left_extra|
                left_indices  = ([indices[0]] + left_extra).sort
                right_indices = (rest - left_extra).sort
                next if right_indices.empty?

                boxes_a = solve_boxes(left_indices,  all_items, cache)
                boxes_b = solve_boxes(right_indices, all_items, cache)

                boxes_a.each do |a|
                  boxes_b.each do |b|
                    combined.concat(combine_sorted_boxes(a, b))
                  end
                end
              end
            end

            pareto_optimal(combined)
          end

        cache[indices] = result
      end

      # Combines two sorted triples [s1,m1,l1] and [s2,m2,l2] along each of
      # the 3 axes (sum one dimension, max the other two), re-sorts each result
      # to model free physical rotation, and returns the Pareto-optimal subset.
      def combine_sorted_boxes(box_a, box_b)
        s1, m1, l1 = box_a
        s2, m2, l2 = box_b

        pareto_optimal([
          [s1 + s2,        [m1, m2].max, [l1, l2].max].sort,
          [[s1, s2].max,   m1 + m2,      [l1, l2].max].sort,
          [[s1, s2].max,   [m1, m2].max, l1 + l2      ].sort
        ])
      end

      # Removes dominated boxes from a collection of sorted triples.
      # Box X dominates box Y if X[i] <= Y[i] for all i with at least one strict.
      def pareto_optimal(boxes)
        boxes.reject do |candidate|
          boxes.any? do |other|
            next false if other.equal?(candidate)
            other[0] <= candidate[0] &&
              other[1] <= candidate[1] &&
              other[2] <= candidate[2] &&
              other != candidate
          end
        end.uniq
      end

      # Returns all distinct sorted [s,m,l] orientations for a line item.
      # For each factorization of qty into (a,b,c) with a*b*c == qty, and for
      # each permutation of (a,b,c) assigned to the item's 3 dimensions, the
      # bounding box is computed and sorted (free rotation). This covers linear
      # stacking, 2-D grids, and 3-D grids (e.g. 2x5 arrangement of 10 items).
      def item_block_orientations(variant, qty)
        dims = variant_dimensions_cm(variant)
        return nil if dims.nil?

        h, w, d = dims
        orientations = []

        qty_factorizations(qty).each do |a, b, c|
          [a, b, c].permutation.each do |fa, fb, fc|
            orientations << [h * fa, w * fb, d * fc].sort
          end
        end

        orientations.uniq
      end

      # Returns all sorted triples [a, b, c] with a <= b <= c and a*b*c == n.
      def qty_factorizations(n)
        result = []
        a = 1
        while a * a * a <= n
          if n % a == 0
            b = a
            while a * b * b <= n
              result << [a, b, n / (a * b)] if (n / a) % b == 0
              b += 1
            end
          end
          a += 1
        end
        result
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

      def smaller_size(a, b)
        return b if a.nil?
        SIZES_ORDERED.index(a) <= SIZES_ORDERED.index(b) ? a : b
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
