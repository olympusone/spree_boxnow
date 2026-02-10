class AddBoxnowToSpreeShippingMethods < ActiveRecord::Migration[8.1]
  def change
    add_column :spree_shipping_methods, :boxnow, :boolean
  end
end
