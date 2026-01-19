# frozen_string_literal: true

module ::VirtualCategory
  class Engine < ::Rails::Engine
    engine_name PLUGIN_NAME
    isolate_namespace VirtualCategory
  end
end
