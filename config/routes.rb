Spree::Core::Engine.add_routes do
  namespace :admin, path: Spree.admin_path do
    post  'boxnow/:order_id/create',        to: 'boxnow#create',        as: :boxnow_create
    get   'boxnow/:order_id/print',         to: 'boxnow#print',         as: :boxnow_print
    post  'boxnow/:order_id/select_locker', to: 'boxnow#select_locker', as: :boxnow_select_locker
  end

  post 'boxnow/select_locker', to: 'boxnow#select_locker', as: :boxnow_select_locker
end
