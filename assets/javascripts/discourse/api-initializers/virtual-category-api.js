import { apiInitializer } from "discourse/lib/api";

export default apiInitializer("1.14.0", (api) => {
  const siteSettings = api.container.lookup("service:site-settings");

  if (!siteSettings.virtual_category_enabled) {
    return;
  }

  api.addCategoryLinkIcon((category) => {
    if (
      category.is_virtual_category ||
      category.custom_fields?.is_virtual_category === true ||
      category.custom_fields?.is_virtual_category === "true"
    ) {
      return "layer-group";
    }
    return null;
  });

  api.modifyClass("model:category", {
    pluginId: "discourse-virtual-category",

    get isVirtualCategory() {
      return (
        this.is_virtual_category ||
        this.custom_fields?.is_virtual_category === true ||
        this.custom_fields?.is_virtual_category === "true"
      );
    },

    get virtualTagNames() {
      if (this.virtual_tag_names) {
        return Array.isArray(this.virtual_tag_names) ? this.virtual_tag_names : [];
      }

      const tags = this.custom_fields?.virtual_tag_names;
      if (!tags) {
        return [];
      }
      if (Array.isArray(tags)) {
        return tags;
      }
      if (typeof tags === "string") {
        return tags.split("|").filter(Boolean);
      }
      return [];
    },

    get virtualTagGroupNames() {
      if (this.virtual_tag_group_names) {
        return Array.isArray(this.virtual_tag_group_names)
          ? this.virtual_tag_group_names
          : [];
      }

      const groups = this.custom_fields?.virtual_tag_group_names;
      if (!groups) {
        return [];
      }
      if (Array.isArray(groups)) {
        return groups;
      }
      if (typeof groups === "string") {
        return groups.split("|").filter(Boolean);
      }
      return [];
    },
  });
});
