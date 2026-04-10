---
title: "Turbo Frames Faceted Search"
---

# Turbo Frames Faceted Search

## Table of Contents

- [Overview](#overview)
- [Implementation](#implementation)
  - [Basic Filter Form with Results Frame](#basic-filter-form-with-results-frame)
  - [Controller with Filter Logic](#controller-with-filter-logic)
  - [Auto-Submit on Filter Change](#auto-submit-on-filter-change)
  - [URL Parameter Preservation](#url-parameter-preservation)
  - [Debounced Text Search](#debounced-text-search)
  - [Combining Filters with Pagination](#combining-filters-with-pagination)
- [Pattern Card](#pattern-card)

## Overview

Faceted search is a common pattern where users apply multiple filters (category, status, date range, search text) and see results update in real time. Turbo Frames make this straightforward: the filter form targets a results frame, and each filter change submits the form to refresh the results.

The architecture is simple:
1. A `<form>` with filter inputs targets a Turbo Frame via `data-turbo-frame`.
2. When any filter changes, the form auto-submits (via Stimulus or `requestSubmit()`).
3. The server applies all active filters and renders results inside a matching `turbo_frame_tag`.
4. Only the results frame updates -- the filter controls, page header, and sidebar stay in place.

This pattern keeps all filter logic on the server (where it belongs), avoids building a client-side filter engine, and works without JavaScript as a normal form submission with full page reload.

## Implementation

### Basic Filter Form with Results Frame

```erb
<%# app/views/products/index.html.erb %>
<h1>Products</h1>

<div class="search-page">
  <aside class="filters">
    <%= form_with url: products_path, method: :get, data: {
      turbo_frame: "products_results",
      controller: "auto-submit",
      auto_submit_delay_value: 300
    } do |f| %>

      <div class="filter-group">
        <%= f.label :search, "Search" %>
        <%= f.search_field :search,
          value: params[:search],
          placeholder: "Search products...",
          data: { action: "input->auto-submit#submit" } %>
      </div>

      <div class="filter-group">
        <%= f.label :category, "Category" %>
        <%= f.select :category,
          options_for_select(Category.pluck(:name, :id), params[:category]),
          { include_blank: "All categories" },
          data: { action: "change->auto-submit#submit" } %>
      </div>

      <div class="filter-group">
        <%= f.label :status, "Status" %>
        <div class="checkbox-group">
          <% %w[active draft archived].each do |status| %>
            <label class="checkbox-label">
              <%= check_box_tag "status[]", status,
                params[:status]&.include?(status),
                data: { action: "change->auto-submit#submit" } %>
              <%= status.titleize %>
            </label>
          <% end %>
        </div>
      </div>

      <div class="filter-group">
        <%= f.label :price_min, "Price range" %>
        <div class="range-inputs">
          <%= f.number_field :price_min,
            value: params[:price_min],
            placeholder: "Min",
            data: { action: "change->auto-submit#submit" } %>
          <span>to</span>
          <%= f.number_field :price_max,
            value: params[:price_max],
            placeholder: "Max",
            data: { action: "change->auto-submit#submit" } %>
        </div>
      </div>

      <div class="filter-group">
        <%= f.label :sort, "Sort by" %>
        <%= f.select :sort,
          options_for_select([
            ["Newest first", "newest"],
            ["Price: low to high", "price_asc"],
            ["Price: high to low", "price_desc"],
            ["Name A-Z", "name_asc"]
          ], params[:sort]),
          {},
          data: { action: "change->auto-submit#submit" } %>
      </div>

      <div class="filter-actions">
        <%= f.submit "Apply filters", class: "btn btn-primary" %>
        <%= link_to "Clear all", products_path, class: "btn btn-secondary" %>
      </div>
    <% end %>
  </aside>

  <main class="results">
    <%= turbo_frame_tag "products_results" do %>
      <div class="results-header">
        <p class="results-count"><%= pluralize(@pagy.count, "product") %> found</p>
      </div>

      <div class="products-grid">
        <%= render @products %>
      </div>

      <nav class="pagination" aria-label="Pagination">
        <%== pagy_nav(@pagy) %>
      </nav>
    <% end %>
  </main>
</div>
```

### Controller with Filter Logic

Keep filter logic in the controller using scopes. This keeps it testable and avoids scattering query logic across service objects.

```ruby
# app/controllers/products_controller.rb
class ProductsController < ApplicationController
  include Pagy::Backend

  def index
    products = Product.all

    products = products.search(params[:search]) if params[:search].present?
    products = products.where(category_id: params[:category]) if params[:category].present?
    products = products.where(status: params[:status]) if params[:status].present?
    products = products.where("price >= ?", params[:price_min]) if params[:price_min].present?
    products = products.where("price <= ?", params[:price_max]) if params[:price_max].present?

    products = apply_sort(products)

    @pagy, @products = pagy(products, items: 24)
  end

  private

  def apply_sort(scope)
    case params[:sort]
    when "price_asc"  then scope.order(price: :asc)
    when "price_desc" then scope.order(price: :desc)
    when "name_asc"   then scope.order(name: :asc)
    else                    scope.order(created_at: :desc) # newest first (default)
    end
  end
end
```

```ruby
# app/models/product.rb
class Product < ApplicationRecord
  belongs_to :category

  scope :search, ->(query) {
    where("name ILIKE :q OR description ILIKE :q", q: "%#{sanitize_sql_like(query)}%")
  }
end
```

### Auto-Submit on Filter Change

This Stimulus controller auto-submits the form when any filter changes, with debouncing for text inputs.

```javascript
// app/javascript/controllers/auto_submit_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    delay: { type: Number, default: 300 }
  }

  submit() {
    clearTimeout(this.timeout)
    this.timeout = setTimeout(() => {
      this.element.requestSubmit()
    }, this.delayValue)
  }

  // For immediate submission (select, checkbox)
  submitNow() {
    clearTimeout(this.timeout)
    this.element.requestSubmit()
  }
}
```

The `requestSubmit()` method triggers form submission through Turbo, respecting the `data-turbo-frame` target. For `<select>` and checkbox changes, you can use `submitNow` for immediate response:

```erb
<%= f.select :category, ...,
  data: { action: "change->auto-submit#submitNow" } %>
```

For text inputs, the debounced `submit` action prevents excessive requests while the user types:

```erb
<%= f.search_field :search, ...,
  data: { action: "input->auto-submit#submit" } %>
```

### URL Parameter Preservation

When the filter form submits via GET, the URL updates with the current filter parameters. This means:
- Users can bookmark or share filtered result pages.
- The browser back button restores previous filter states.
- Refreshing the page preserves the active filters.

Ensure all filter inputs use `params` values as their default:

```erb
<%= f.search_field :search, value: params[:search] %>
<%= f.select :category, ..., selected: params[:category] %>
```

For multi-value filters (checkboxes), use array parameter names:

```erb
<%= check_box_tag "status[]", "active", params[:status]&.include?("active") %>
```

### Debounced Text Search

For search fields that query on every keystroke, add debouncing to avoid overwhelming the server:

```javascript
// app/javascript/controllers/search_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "count"]
  static values = { delay: { type: Number, default: 300 } }

  search() {
    clearTimeout(this.timeout)
    this.timeout = setTimeout(() => {
      this.element.requestSubmit()
    }, this.delayValue)
  }

  // Clear search and resubmit
  clear() {
    this.inputTarget.value = ""
    this.element.requestSubmit()
  }
}
```

```erb
<%= form_with url: products_path, method: :get, data: {
  turbo_frame: "products_results",
  controller: "search",
  search_delay_value: 300
} do |f| %>
  <div class="search-input-wrapper">
    <%= f.search_field :search,
      value: params[:search],
      placeholder: "Search...",
      data: { search_target: "input", action: "input->search#search" },
      autofocus: params[:search].present? %>
    <% if params[:search].present? %>
      <button type="button" data-action="search#clear" class="search-clear">
        Clear
      </button>
    <% end %>
  </div>
<% end %>
```

### Combining Filters with Pagination

When filters and pagination coexist, pagination links must preserve the current filter parameters. Since both the filter results and pagination controls are inside the same Turbo Frame, this works automatically -- the pagination links generated by Pagy or Kaminari include all current query parameters.

However, when a filter changes, reset pagination to page 1. The simplest approach is to not include a `page` parameter in the filter form:

```erb
<%# The form does NOT include a page field, so filtering always starts at page 1 %>
<%= form_with url: products_path, method: :get, data: {
  turbo_frame: "products_results",
  controller: "auto-submit"
} do |f| %>
  <%# Filter inputs here -- no page input %>
<% end %>
```

Pagination links (generated by the pagination gem) naturally include `?page=2&search=foo&category=3`, preserving all filters while changing the page.

## Pattern Card

### GOOD: Frame-Targeted Filter Form with Auto-Submit

```erb
<%# Filters live OUTSIDE the results frame %>
<aside class="filters">
  <%= form_with url: products_path, method: :get, data: {
    turbo_frame: "products_results",
    controller: "auto-submit"
  } do |f| %>
    <%= f.select :category, Category.pluck(:name, :id),
      { include_blank: "All" },
      data: { action: "change->auto-submit#submit" } %>
    <%= f.search_field :search, value: params[:search],
      data: { action: "input->auto-submit#submit" } %>
  <% end %>
</aside>

<%# Only the results frame updates on filter change %>
<main>
  <%= turbo_frame_tag "products_results" do %>
    <%= render @products %>
    <%== pagy_nav(@pagy) %>
  <% end %>
</main>
```

Filters stay visible and interactive while results update. The URL reflects the current filters. Without JavaScript, the form submits normally and renders a full page. All filter logic lives in the controller, keeping the frontend simple.

### BAD: Custom AJAX Search with Client-Side Filtering

```erb
<aside class="filters">
  <select id="category-filter" onchange="filterProducts()">
    <option value="">All</option>
    <% Category.all.each do |c| %>
      <option value="<%= c.id %>"><%= c.name %></option>
    <% end %>
  </select>
  <input type="text" id="search-input" onkeyup="filterProducts()">
</aside>

<main>
  <div id="products-list">
    <%= render @products %>
  </div>
</main>

<script>
  async function filterProducts() {
    const category = document.getElementById('category-filter').value;
    const search = document.getElementById('search-input').value;

    const response = await fetch(`/products.json?category=${category}&search=${search}`);
    const html = await response.text();
    document.getElementById('products-list').innerHTML = html;
  }
</script>
```

This approach bypasses Turbo entirely, requiring custom fetch logic and manual DOM manipulation. The URL does not update, so filters cannot be bookmarked or shared. The browser back button does not undo filter changes. There is no loading state, no error handling, no debouncing, and no graceful degradation without JavaScript. It also duplicates the rendering logic that the server already provides through views and partials.
