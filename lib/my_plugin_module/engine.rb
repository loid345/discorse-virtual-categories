# frozen_string_literal: true

module ::MyPluginModule
  class Engine < ::Rails::Engine
    engine_name MyPluginModule::PLUGIN_NAME
    isolate_namespace VirtualCategory
  end
end
