module SpreeBoxnow
  class Engine < Rails::Engine
    require 'spree/core'
    isolate_namespace Spree
    engine_name 'spree_boxnow'

    # use rspec for tests
    config.generators do |g|
      g.test_framework :rspec
    end

    initializer 'spree_boxnow.environment', before: :load_config_initializers do |_app|
      SpreeBoxnow::Config = SpreeBoxnow::Configuration.new
    end

    initializer 'spree_boxnow.assets' do |app|
      app.config.assets.paths << root.join('app/javascript')
      app.config.assets.precompile += %w[spree_boxnow_manifest]
    end

    initializer 'spree_boxnow.importmap', after: 'spree.admin.importmap' do |app|
      app.config.spree_admin.importmap.draw(root.join('config/importmap.rb'))
    end

    initializer 'spree_boxnow.cache_sweeper', before: 'spree.admin.importmap.cache_sweeper' do |app|
      if app.config.importmap.sweep_cache && app.config.reloading_enabled?
        app.config.spree_admin.cache_sweepers << root.join('app/javascript')
      end
    end

    def self.activate
      Dir.glob(File.join(File.dirname(__FILE__), '../../app/**/*_decorator*.rb')) do |c|
        Rails.configuration.cache_classes ? require(c) : load(c)
      end
    end

    config.to_prepare(&method(:activate).to_proc)
  end
end
