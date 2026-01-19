# frozen_string_literal: true

# name: discourse-virtual-categories
# about: Adds virtual categories that aggregate topics by tags while respecting permissions.
# version: 1.0.0
# authors: OpenAI
# url: https://github.com/example/discourse-virtual-categories
# required_version: 2.7.0

enabled_site_setting :virtual_category_enabled

register_asset "stylesheets/virtual-category.scss"

module ::VirtualCategory
  PLUGIN_NAME = "discourse-virtual-categories"
end

require_relative "lib/virtual_category/engine"

after_initialize do
  Category.register_custom_field_type("is_virtual_category", :boolean)
  Category.register_custom_field_type("virtual_tag_names", :string)

  Site.preloaded_category_custom_fields << "is_virtual_category"
  Site.preloaded_category_custom_fields << "virtual_tag_names"

  add_to_serializer(:category, :is_virtual_category) do
    object.custom_fields["is_virtual_category"] == true ||
      object.custom_fields["is_virtual_category"] == "true"
  end

  add_to_serializer(:category, :virtual_tag_names) do
    raw = object.custom_fields["virtual_tag_names"]
    return [] if raw.blank?

    raw.is_a?(Array) ? raw : raw.to_s.split("|")
  end

  add_to_class(:category, :virtual_category?) do
    custom_fields["is_virtual_category"] == true ||
      custom_fields["is_virtual_category"] == "true"
  end

  add_to_class(:category, :virtual_tag_ids) do
    names = custom_fields["virtual_tag_names"]
    return [] if names.blank?

    name_list = names.is_a?(Array) ? names : names.to_s.split("|")
    Tag.where(name: name_list).pluck(:id)
  end

  require_relative "lib/virtual_category/topic_query_extension"

  reloadable_patch do |plugin|
    TopicQuery.prepend(VirtualCategory::TopicQueryExtension)
  end
end
