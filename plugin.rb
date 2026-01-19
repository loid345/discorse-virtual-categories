# frozen_string_literal: true

# name: discourse-virtual-category
# about: Allows categories to aggregate topics from other categories based on tag rules
# meta_topic_id: 12345
# version: 1.0.0
# authors: Discourse
# url: https://github.com/discourse/discourse-virtual-category
# required_version: 3.2.0

enabled_site_setting :virtual_category_enabled

register_asset "stylesheets/virtual-category.scss"

module ::VirtualCategory
  PLUGIN_NAME = "discourse-virtual-category"
end

require_relative "lib/virtual_category/engine"

after_initialize do
  Category.register_custom_field_type("is_virtual_category", :boolean)
  Category.register_custom_field_type("virtual_tag_names", :string)
  Category.register_custom_field_type("virtual_tag_group_names", :string)

  Site.preloaded_category_custom_fields << "is_virtual_category"
  Site.preloaded_category_custom_fields << "virtual_tag_names"
  Site.preloaded_category_custom_fields << "virtual_tag_group_names"

  add_to_serializer(:category, :is_virtual_category) do
    value = object.custom_fields["is_virtual_category"]
    value == true || value == "true"
  end

  add_to_serializer(:category, :virtual_tag_names) do
    raw = object.custom_fields["virtual_tag_names"]
    raw.is_a?(Array) ? raw : raw.to_s.split("|").reject(&:blank?)
  end

  add_to_serializer(:category, :virtual_tag_group_names) do
    raw = object.custom_fields["virtual_tag_group_names"]
    raw.is_a?(Array) ? raw : raw.to_s.split("|").reject(&:blank?)
  end

  add_to_class(:category, :virtual_category?) do
    return false unless SiteSetting.virtual_category_enabled

    value = custom_fields["is_virtual_category"]
    value == true || value == "true"
  end

  add_to_class(:category, :virtual_tag_names_array) do
    raw = custom_fields["virtual_tag_names"]
    raw.is_a?(Array) ? raw : raw.to_s.split("|").reject(&:blank?)
  end

  add_to_class(:category, :virtual_tag_group_names_array) do
    raw = custom_fields["virtual_tag_group_names"]
    raw.is_a?(Array) ? raw : raw.to_s.split("|").reject(&:blank?)
  end

  add_to_class(:category, :virtual_tag_ids) do
    @virtual_tag_ids ||= begin
      tag_ids = Tag.where(name: virtual_tag_names_array).pluck(:id)
      group_tag_ids = TagGroup
        .joins(:tag_group_tags)
        .where(name: virtual_tag_group_names_array)
        .pluck("tag_group_tags.tag_id")

      (tag_ids + group_tag_ids).uniq
    end
  end

  add_model_callback(:category, :before_validation) do
    next unless virtual_category?

    max_tags = SiteSetting.virtual_category_max_tags
    max_tag_groups = SiteSetting.virtual_category_max_tag_groups

    if virtual_tag_names_array.size > max_tags
      errors.add(:base, I18n.t("virtual_category.errors.max_tags", count: max_tags))
    end

    if virtual_tag_group_names_array.size > max_tag_groups
      errors.add(
        :base,
        I18n.t("virtual_category.errors.max_tag_groups", count: max_tag_groups)
      )
    end
  end

  require_relative "lib/virtual_category/topic_query_extension"

  reloadable_patch do |_plugin|
    TopicQuery.prepend(VirtualCategory::TopicQueryExtension)
  end
end
