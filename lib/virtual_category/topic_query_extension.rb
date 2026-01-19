# frozen_string_literal: true

module VirtualCategory
  module TopicQueryExtension
    extend ActiveSupport::Concern

    def list_category(category)
      return super unless SiteSetting.virtual_category_enabled
      return super unless SiteSetting.tagging_enabled
      return super unless category&.virtual_category?

      tag_ids = category.virtual_tag_ids
      return super if tag_ids.empty?

      create_list(:category, { category: category.id }, category) do |topics|
        VirtualCategoryFilter.new(
          topics: topics,
          category: category,
          tag_ids: tag_ids,
          guardian: @guardian
        ).filter
      end
    end

    class VirtualCategoryFilter
      def initialize(topics:, category:, tag_ids:, guardian:)
        @topics = topics
        @category = category
        @tag_ids = tag_ids
        @guardian = guardian
      end

      def filter
        result = @topics.unscope(where: :category_id)
        result = apply_union_filter(result)
        result = apply_security_filter(result)
        result.distinct
      end

      private

      def apply_union_filter(topics)
        tagged_topic_ids_subquery = TopicTag
          .where(tag_id: @tag_ids)
          .select(:topic_id)

        if @guardian.is_admin?
          topics.where(
            "topics.category_id = :cat_id OR topics.id IN (:tagged_ids)",
            cat_id: @category.id,
            tagged_ids: tagged_topic_ids_subquery
          )
        else
          allowed_ids = accessible_category_ids

          topics.where(
            "(topics.category_id = :cat_id) OR (topics.id IN (:tagged_ids) AND topics.category_id IN (:allowed_ids))",
            cat_id: @category.id,
            tagged_ids: tagged_topic_ids_subquery,
            allowed_ids: allowed_ids
          )
        end
      end

      def apply_security_filter(topics)
        return topics if @guardian.is_admin?

        allowed_ids = accessible_category_ids
        allowed_ids << @category.id unless allowed_ids.include?(@category.id)

        topics.where(category_id: allowed_ids)
      end

      def accessible_category_ids
        @accessible_category_ids ||= begin
          if @guardian.is_staff?
            Category.where(read_restricted: false).pluck(:id) +
              Category.secured(@guardian).pluck(:id)
          elsif @guardian.user
            Category.secured(@guardian).pluck(:id)
          else
            Category.where(read_restricted: false).pluck(:id)
          end
        end
      end
    end
  end
end
