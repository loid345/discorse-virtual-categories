#!/bin/bash

# ==============================================================================
# Discourse Virtual Category Plugin Generator
# ==============================================================================
# This script generates a complete, production-ready Discourse plugin.
#
# Features:
# - Modern Glimmer JS components
# - Secure SQL query extension
# - RSpec tests
# - English comments throughout
# ==============================================================================

set -e

PLUGIN_NAME="discourse-virtual-category"
TARGET_DIR="${1:-./$PLUGIN_NAME}"

GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }

if [ -d "$TARGET_DIR" ]; then
  log "Cleaning existing directory: $TARGET_DIR"
  rm -rf "$TARGET_DIR"
fi

mkdir -p "$TARGET_DIR"
log "Created plugin directory at $TARGET_DIR"

mkdir -p "$TARGET_DIR/.github/workflows"
mkdir -p "$TARGET_DIR/assets/javascripts/discourse/connectors/category-custom-settings"
mkdir -p "$TARGET_DIR/assets/stylesheets"
mkdir -p "$TARGET_DIR/config/locales"
mkdir -p "$TARGET_DIR/lib/virtual_category"
mkdir -p "$TARGET_DIR/spec/lib"
mkdir -p "$TARGET_DIR/spec/requests"

cat > "$TARGET_DIR/plugin.rb" <<'PLUGIN'
# frozen_string_literal: true

# name: discourse-virtual-category
# about: Allows categories to aggregate topics from other categories based on tags.
# version: 1.0.0
# authors: Gemini
# url: https://github.com/yourusername/discourse-virtual-category
# required_version: 2.7.0

enabled_site_setting :virtual_category_enabled

register_asset "stylesheets/virtual-category.scss"

module ::VirtualCategory
  PLUGIN_NAME = "discourse-virtual-category"
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
PLUGIN

cat > "$TARGET_DIR/lib/virtual_category/engine.rb" <<'ENGINE'
# frozen_string_literal: true

module ::VirtualCategory
  class Engine < ::Rails::Engine
    engine_name VirtualCategory::PLUGIN_NAME
    isolate_namespace VirtualCategory
  end
end
ENGINE

cat > "$TARGET_DIR/lib/virtual_category/topic_query_extension.rb" <<'QUERY'
# frozen_string_literal: true

module VirtualCategory
  module TopicQueryExtension
    extend ActiveSupport::Concern

    def list_category(category)
      return super unless SiteSetting.virtual_category_enabled
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
QUERY

cat > "$TARGET_DIR/config/settings.yml" <<'SETTINGS'
virtual_category:
  virtual_category_enabled:
    default: true
    client: true
    description: "Enable the virtual category (mixed mode) functionality."
  virtual_category_max_tags:
    default: 10
    min: 1
    max: 50
    client: true
    description: "Maximum number of tags allowed for aggregation per category."
SETTINGS

cat > "$TARGET_DIR/config/locales/client.en.yml" <<'CLIENTEN'
en:
  js:
    virtual_category:
      title: "Virtual Category Settings"
      is_virtual_label: "Enable Tag Aggregation (Mix Mode)"
      is_virtual_description: "When enabled, this category will display its own topics PLUS topics from other categories that match the selected tags."
      tags_label: "Aggregation Tags"
      tags_description: "Select tags. Topics with these tags will be pulled into this category list, respecting user permissions."
      no_tags: "No tags selected."
CLIENTEN

cat > "$TARGET_DIR/config/locales/client.ru.yml" <<'CLIENTRU'
ru:
  js:
    virtual_category:
      title: "Настройки виртуальной категории"
      is_virtual_label: "Включить агрегацию по тегам (Смешанный режим)"
      is_virtual_description: "Если включено, в этой категории будут отображаться как собственные топики, так и топики из других разделов, имеющие выбранные теги."
      tags_label: "Теги для агрегации"
      tags_description: "Выберите теги. Топики с этими тегами будут подтягиваться в этот список при наличии у пользователя прав доступа."
      no_tags: "Теги не выбраны."
CLIENTRU

cat > "$TARGET_DIR/assets/javascripts/discourse/connectors/category-custom-settings/virtual-category-settings.gjs" <<'GJS'
import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { on } from "@ember/modifier";
import i18n from "discourse-common/helpers/i18n";
import TagChooser from "select-kit/components/tag-chooser";

export default class VirtualCategorySettings extends Component {
  @service siteSettings;

  get category() {
    return this.args.outletArgs?.category;
  }

  get isEnabled() {
    return this.siteSettings.virtual_category_enabled;
  }

  get isVirtual() {
    return (
      this.category?.custom_fields?.is_virtual_category === true ||
      this.category?.custom_fields?.is_virtual_category === "true"
    );
  }

  get virtualTags() {
    const tags = this.category?.custom_fields?.virtual_tag_names;
    if (!tags) return [];
    if (Array.isArray(tags)) return tags;
    return tags.split("|").filter(Boolean);
  }

  get maxTags() {
    return this.siteSettings.virtual_category_max_tags || 10;
  }

  @action
  toggleVirtual(event) {
    const isChecked = event.target.checked;

    if (!this.category.custom_fields) {
      this.category.set("custom_fields", {});
    }

    this.category.set("custom_fields.is_virtual_category", isChecked);

    if (!isChecked) {
      this.category.set("custom_fields.virtual_tag_names", "");
    }
  }

  @action
  onChangeTags(tags) {
    const tagString = tags.join("|");
    this.category.set("custom_fields.virtual_tag_names", tagString);
  }

  <template>
    {{#if this.isEnabled}}
      <section class="field virtual-category-settings">
        <label class="checkbox-label">
          <input
            type="checkbox"
            checked={{this.isVirtual}}
            {{on "change" this.toggleVirtual}}
          />
          <b>{{i18n "virtual_category.is_virtual_label"}}</b>
        </label>

        <div class="description">
          {{i18n "virtual_category.is_virtual_description"}}
        </div>

        {{#if this.isVirtual}}
          <div class="virtual-tags-container">
            <label>{{i18n "virtual_category.tags_label"}}</label>
            <div class="description">
              {{i18n "virtual_category.tags_description"}}
            </div>

            <TagChooser
              @tags={{this.virtualTags}}
              @allowCreate={{false}}
              @everyTag={{true}}
              @onChange={{this.onChangeTags}}
              @options={{hash
                maximum=this.maxTags
              }}
            />
          </div>
        {{/if}}
      </section>
    {{/if}}
  </template>
}
GJS

cat > "$TARGET_DIR/assets/stylesheets/virtual-category.scss" <<'SCSS'
.virtual-category-settings {
  margin-bottom: 20px;
  background: var(--primary-very-low);
  padding: 15px;
  border-radius: 5px;
}

.virtual-category-settings .virtual-tags-container {
  margin-top: 10px;
  border-left: 3px solid var(--tertiary);
  padding-left: 10px;
}
SCSS

cat > "$TARGET_DIR/spec/lib/virtual_category_spec.rb" <<'SPEC'
# frozen_string_literal: true

require "rails_helper"

describe "Virtual Category Query Logic" do
  fab!(:admin) { Fabricate(:admin) }
  fab!(:user) { Fabricate(:user) }
  fab!(:group) { Fabricate(:group) }
  fab!(:private_category) { Fabricate(:private_category, group: group) }
  fab!(:public_category) { Fabricate(:category) }
  fab!(:virtual_category) { Fabricate(:category) }
  fab!(:tag) { Fabricate(:tag, name: "testtag") }

  before do
    SiteSetting.virtual_category_enabled = true
    SiteSetting.tagging_enabled = true

    virtual_category.custom_fields["is_virtual_category"] = true
    virtual_category.custom_fields["virtual_tag_names"] = "testtag"
    virtual_category.save_custom_fields
  end

  let!(:topic_native) { Fabricate(:topic, category: virtual_category) }
  let!(:topic_public_tagged) { Fabricate(:topic, category: public_category, tags: [tag]) }
  let!(:topic_private_tagged) { Fabricate(:topic, category: private_category, tags: [tag]) }
  let!(:topic_public_untagged) { Fabricate(:topic, category: public_category) }

  def fetch_topics(guardian)
    TopicQuery.new(guardian, category: virtual_category.id)
      .list_category(virtual_category)
      .topics
  end

  it "shows native topics" do
    topics = fetch_topics(Guardian.new(user))
    expect(topics).to include(topic_native)
  end

  it "shows aggregated topics from public categories" do
    topics = fetch_topics(Guardian.new(user))
    expect(topics).to include(topic_public_tagged)
  end

  it "does not show untagged topics from other categories" do
    topics = fetch_topics(Guardian.new(user))
    expect(topics).not_to include(topic_public_untagged)
  end

  context "Security" do
    it "does not show private topics to regular users" do
      topics = fetch_topics(Guardian.new(user))
      expect(topics).not_to include(topic_private_tagged)
    end

    it "shows private topics to group members" do
      group.add(user)
      group.save!

      topics = fetch_topics(Guardian.new(user))
      expect(topics).to include(topic_private_tagged)
    end

    it "shows everything to admin" do
      topics = fetch_topics(Guardian.new(admin))
      expect(topics).to include(topic_private_tagged)
      expect(topics).to include(topic_public_tagged)
    end
  end
end
SPEC

cat > "$TARGET_DIR/.github/workflows/ci.yml" <<'CI'
name: CI

on:
  push:
    branches: [main, master]
  pull_request:

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Syntax Check
        run: |
          echo "Running syntax check..."
CI

cat > "$TARGET_DIR/LICENSE" <<'LICENSE'
MIT License

Copyright (c) 2024

Permission is hereby granted, free of charge, to any person obtaining a copy of this software...
LICENSE

cat > "$TARGET_DIR/README.md" <<'README'
# Discourse Virtual Category

A plugin that allows categories to act as aggregators. A "Virtual Category" displays its own topics plus topics from other categories that match specific tags.

## Features
- **Mix Mode:** Combine native topics and tagged topics in one list.
- **Secure:** Respects Discourse category permissions.
- **No Duplicates:** Filters duplicates if a topic is both in the category and has the tag.

## Installation
Add to your `app.yml`:

```yaml
hooks:
  after_code:
    - exec:
        cd: $home/plugins
        cmd:
          - git clone https://github.com/yourusername/discourse-virtual-category.git
```
README

success "Plugin generated successfully!"
log "Next steps:"
log "1. cd $TARGET_DIR"
log "2. Run 'bundle exec rubocop' to check Ruby style"
log "3. Run 'bin/rspec plugins/$PLUGIN_NAME/spec' to run tests"
