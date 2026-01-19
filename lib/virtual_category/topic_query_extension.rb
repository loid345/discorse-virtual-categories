# frozen_string_literal: true

module VirtualCategory
  module TopicQueryExtension
    extend ActiveSupport::Concern

    def list_category(category)
      return super unless should_apply_virtual_filter?(category)

      tag_ids = category.virtual_tag_ids
      return super if tag_ids.empty?

      create_list(:category, { category: category.id }, category) do |topics|
        VirtualCategoryFilter.new(
          topics: topics,
          category: category,
          tag_ids: tag_ids,
          guardian: @guardian
        ).apply
      end
    end

    private

    def should_apply_virtual_filter?(category)
      SiteSetting.virtual_category_enabled && category&.virtual_category?
    end
  end

  class VirtualCategoryFilter
    def initialize(topics:, category:, tag_ids:, guardian:)
      @topics = topics
      @category = category
      @tag_ids = tag_ids
      @guardian = guardian
    end

    def apply
      result = @topics
      result = result.unscope(where: :category_id)
      result = apply_virtual_filter(result)
      result = apply_visibility_filters(result)
      result.distinct
    end

    private

    def apply_virtual_filter(topics)
      if @guardian.is_admin?
        apply_admin_filter(topics)
      else
        apply_user_filter(topics)
      end
    end

    def apply_admin_filter(topics)
      topics.joins(tag_join_sql).where(
        "topics.category_id = :category_id OR topic_tags.id IS NOT NULL",
        category_id: @category.id
      )
    end

    def apply_user_filter(topics)
      allowed_ids = accessible_category_ids
      return topics.where(category_id: @category.id) if allowed_ids.empty?

      topics.joins(tag_join_sql).where(
        "topics.category_id = :category_id OR "
          "(topic_tags.id IS NOT NULL AND topics.category_id IN (:allowed_ids))",
        category_id: @category.id,
        allowed_ids: allowed_ids
      )
    end

    def tag_join_sql
      tag_ids_sql = @tag_ids.map(&:to_i).join(",")
      "LEFT JOIN topic_tags ON topic_tags.topic_id = topics.id " \
        "AND topic_tags.tag_id IN (#{tag_ids_sql})"
    end

    def accessible_category_ids
      @accessible_category_ids ||= begin
        if @guardian.is_staff?
          public_ids = Category.where(read_restricted: false).pluck(:id)
          secured_ids = Category.secured(@guardian).pluck(:id)
          (public_ids + secured_ids).uniq
        elsif @guardian.user
          Category.secured(@guardian).pluck(:id)
        else
          Category.where(read_restricted: false).pluck(:id)
        end
      end
    end

    def apply_visibility_filters(topics)
      topics = topics.where(archetype: Archetype.default)
      topics = topics.where(visible: true) unless @guardian.is_staff?
      topics = topics.where(deleted_at: nil) unless @guardian.can_see_deleted_topics?(@category)
      topics
    end
  end
end
