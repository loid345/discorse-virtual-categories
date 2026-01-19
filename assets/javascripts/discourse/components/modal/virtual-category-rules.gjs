import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { on } from "@ember/modifier";
import DModal from "discourse/components/d-modal";
import i18n from "discourse-common/helpers/i18n";
import TagChooser from "select-kit/components/tag-chooser";
import { ajax } from "discourse/lib/ajax";

export default class VirtualCategoryRules extends Component {
  @service siteSettings;

  @tracked tagGroups = [];
  @tracked isLoading = true;
  @tracked search = "";

  constructor() {
    super(...arguments);
    this.loadTagGroups();
  }

  get category() {
    return this.args.model?.category;
  }

  get selectedTags() {
    const raw = this.category?.custom_fields?.virtual_tag_names;
    if (!raw) {
      return [];
    }
    if (Array.isArray(raw)) {
      return raw;
    }
    return raw.split("|").filter(Boolean);
  }

  get selectedTagGroups() {
    const raw = this.category?.custom_fields?.virtual_tag_group_names;
    if (!raw) {
      return [];
    }
    if (Array.isArray(raw)) {
      return raw;
    }
    return raw.split("|").filter(Boolean);
  }

  get filteredTagGroups() {
    const term = this.search.trim().toLowerCase();
    if (!term) {
      return this.tagGroups;
    }
    return this.tagGroups.filter((group) => group.name.toLowerCase().includes(term));
  }

  get maxTags() {
    return this.siteSettings.virtual_category_max_tags || 20;
  }

  get maxTagGroups() {
    return this.siteSettings.virtual_category_max_tag_groups || 20;
  }

  async loadTagGroups() {
    try {
      const response = await ajax("/tag_groups.json");
      this.tagGroups = response?.tag_groups || [];
    } catch {
      this.tagGroups = [];
    } finally {
      this.isLoading = false;
    }
  }

  @action
  handleTagsChange(tags) {
    this.category.set("custom_fields.virtual_tag_names", tags.join("|"));
  }

  @action
  handleSearch(event) {
    this.search = event.target.value;
  }

  @action
  toggleTagGroup(event) {
    const name = event.target.dataset.groupName;
    const selected = new Set(this.selectedTagGroups);
    if (event.target.checked) {
      if (selected.size >= this.maxTagGroups) {
        event.target.checked = false;
        return;
      }
      selected.add(name);
    } else {
      selected.delete(name);
    }
    this.category.set(
      "custom_fields.virtual_tag_group_names",
      Array.from(selected).join("|")
    );
  }

  <template>
    <DModal
      @title={{i18n "virtual_category.configure_rules"}}
      @closeModal={{@closeModal}}
    >
      <div class="virtual-category-modal">
        <section class="virtual-category-modal-section">
          <h3>{{i18n "virtual_category.tags_title"}}</h3>
          <p class="field-description">
            {{i18n "virtual_category.tags_description"}}
          </p>
          <TagChooser
            @tags={{this.selectedTags}}
            @onChange={{this.handleTagsChange}}
            @options={{hash allowAny=false maximum=this.maxTags}}
            class="virtual-tags-chooser"
          />
        </section>

        <section class="virtual-category-modal-section">
          <h3>{{i18n "virtual_category.tag_groups_title"}}</h3>
          <p class="field-description">
            {{i18n "virtual_category.tag_groups_description"}}
          </p>
          <input
            class="virtual-category-search-input"
            type="text"
            value={{this.search}}
            placeholder={{i18n "virtual_category.tag_groups_search_placeholder"}}
            {{on "input" this.handleSearch}}
          />

          {{#if this.isLoading}}
            <p class="field-description">...</p>
          {{else}}
            {{#if this.filteredTagGroups.length}}
              <ul class="virtual-category-group-list">
                {{#each this.filteredTagGroups as |group|}}
                  <li>
                    <label class="checkbox-label">
                      <input
                        type="checkbox"
                        data-group-name={{group.name}}
                        checked={{this.selectedTagGroups.includes group.name}}
                        {{on "change" this.toggleTagGroup}}
                      />
                      <span class="label-text">{{group.name}}</span>
                    </label>
                  </li>
                {{/each}}
              </ul>
            {{else}}
              <p class="virtual-category-empty">
                {{i18n "virtual_category.tag_groups_empty"}}
              </p>
            {{/if}}
          {{/if}}
        </section>
      </div>
    </DModal>
  </template>
}
