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
