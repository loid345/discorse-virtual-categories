# frozen_string_literal: true

# Backwards-compatibility shim for older plugin skeleton references.
module ::MyPluginModule
  class Engine < ::Rails::Engine
    engine_name VirtualCategory::PLUGIN_NAME
    isolate_namespace VirtualCategory
  end
end
