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
