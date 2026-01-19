import { apiInitializer } from "discourse/lib/api";
import { parseVirtualCategoryList } from "discourse/lib/virtual-category-utils";

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

      return parseVirtualCategoryList(this.custom_fields?.virtual_tag_names);
    },

    get virtualTagGroupNames() {
      if (this.virtual_tag_group_names) {
        return Array.isArray(this.virtual_tag_group_names)
          ? this.virtual_tag_group_names
          : [];
      }

      return parseVirtualCategoryList(this.custom_fields?.virtual_tag_group_names);
    },
  });
});
