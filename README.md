# Discourse Virtual Categories

This plugin adds **virtual categories** that aggregate topics from other categories based on tags while still respecting Discourse permissions.

## Features
- **Mixed lists:** Show native topics plus tagged topics from other categories.
- **Secure by default:** Uses Guardian-aware category scopes to avoid leaking private topics.
- **Glimmer UI:** Category settings UI uses modern Ember/Glimmer.

## Configuration
1. Enable **Virtual Category** in site settings.
2. In a category’s custom settings, toggle **Enable Tag Aggregation**.
3. Select the tags to aggregate.

## Development
- Run Ruby specs: `bin/rspec plugins/discorse-virtual-categories/spec`
