import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { on } from "@ember/modifier";
import i18n from "discourse-common/helpers/i18n";
import icon from "discourse-common/helpers/d-icon";
import { showModal } from "discourse/lib/show-modal";

export default class VirtualCategorySettings extends Component {
  @service siteSettings;

  get category() {
    return this.args.outletArgs?.category;
  }

  get isFeatureEnabled() {
    return this.siteSettings.virtual_category_enabled;
  }

  get isVirtualEnabled() {
    const value = this.category?.custom_fields?.is_virtual_category;
    return value === true || value === "true";
  }

  get selectedTags() {
    const raw = this.category?.custom_fields?.virtual_tag_names;
    if (!raw) {
      return [];
    }
    if (Array.isArray(raw)) {
      return raw;
    }
    if (typeof raw === "string") {
      return raw.split("|").filter(Boolean);
    }
    return [];
  }

  get selectedTagGroups() {
    const raw = this.category?.custom_fields?.virtual_tag_group_names;
    if (!raw) {
      return [];
    }
    if (Array.isArray(raw)) {
      return raw;
    }
    if (typeof raw === "string") {
      return raw.split("|").filter(Boolean);
    }
    return [];
  }

  @action
  handleVirtualToggle(event) {
    const isEnabled = event.target.checked;

    if (!this.category.custom_fields) {
      this.category.set("custom_fields", {});
    }

    this.category.set("custom_fields.is_virtual_category", isEnabled);

    if (isEnabled) {
      this.openRulesModal();
    }
  }

  @action
  openRulesModal() {
    showModal("virtual-category-rules", {
      model: {
        category: this.category,
      },
    });
  }

  <template>
    {{#if this.isFeatureEnabled}}
      <section class="field virtual-category-section">
        <div class="virtual-category-header">
          {{icon "layer-group"}}
          <span class="section-title">{{i18n "virtual_category.title"}}</span>
        </div>

        <div class="virtual-category-toggle">
          <label class="checkbox-label">
            <input
              type="checkbox"
              checked={{this.isVirtualEnabled}}
              {{on "change" this.handleVirtualToggle}}
            />
            <span class="label-text">{{i18n "virtual_category.enable_label"}}</span>
          </label>
          <p class="field-description">
            {{i18n "virtual_category.enable_description"}}
          </p>
        </div>

        {{#if this.isVirtualEnabled}}
          <div class="virtual-category-rules">
            <div class="virtual-category-summary">
              <div>
                <strong>{{i18n "virtual_category.tags_title"}}:</strong>
                {{#if this.selectedTags.length}}
                  <span>{{this.selectedTags.join ", "}}</span>
                {{else}}
                  <span>—</span>
                {{/if}}
              </div>
              <div>
                <strong>{{i18n "virtual_category.tag_groups_title"}}:</strong>
                {{#if this.selectedTagGroups.length}}
                  <span>{{this.selectedTagGroups.join ", "}}</span>
                {{else}}
                  <span>—</span>
                {{/if}}
              </div>
            </div>
            <button
              type="button"
              class="btn btn-primary"
              {{on "click" this.openRulesModal}}
            >
              {{i18n "virtual_category.configure_rules"}}
            </button>
          </div>
        {{/if}}
      </section>
    {{/if}}
  </template>
}
