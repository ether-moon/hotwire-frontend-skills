---
title: "Search with Faceted Filters and Pagination"
---

Product catalog with a filter sidebar, text search, sort, and paginated results. Filters auto-submit via Stimulus to update a results Turbo Frame without full page reloads.

**Patterns combined:** Faceted search, pagination, auto-submit, Turbo Frames

### Controller

```ruby
# app/controllers/products_controller.rb
class ProductsController < ApplicationController
  include Pagy::Backend

  def index
    scope = Product.includes(:category, :brand).with_attached_image

    scope = scope.search(params[:q]) if params[:q].present?
    scope = scope.where(category_id: params[:category]) if params[:category].present?
    scope = scope.where(brand_id: params[:brand]) if params[:brand].present?
    scope = scope.where(status: params[:status]) if params[:status].present?
    scope = scope.in_price_range(params[:price_min], params[:price_max])

    scope = apply_sort(scope, params[:sort])

    @pagy, @products = pagy(scope, items: 24)
    @categories = Category.ordered
    @brands = Brand.with_products
    @active_filters_count = count_active_filters
  end

  private

  def apply_sort(scope, sort)
    case sort
    when "price_asc"    then scope.order(price: :asc)
    when "price_desc"   then scope.order(price: :desc)
    when "newest"       then scope.order(created_at: :desc)
    when "best_selling" then scope.order(sales_count: :desc)
    else                     scope.order(featured: :desc, created_at: :desc)
    end
  end

  def count_active_filters
    [:q, :category, :brand, :status, :price_min, :price_max].count { |k| params[k].present? }
  end
end
```

### View

The filter sidebar lives **outside** the results frame so it persists across updates. The form targets the frame via `data-turbo-frame`.

```erb
<%# app/views/products/index.html.erb %>
<div class="catalog-layout">
  <%# Filter sidebar stays outside the results frame %>
  <aside class="catalog-filters">
    <%= form_with url: products_path, method: :get, data: {
      turbo_frame: "products_results",
      controller: "auto-submit",
      auto_submit_delay_value: 300
    } do |f| %>
      <div class="filter-section">
        <h3>Search</h3>
        <%= f.search_field :q, value: params[:q], placeholder: "Search products...",
          data: { action: "input->auto-submit#submit" } %>
      </div>

      <div class="filter-section">
        <h3>Category</h3>
        <%= f.select :category,
          options_for_select(@categories.map { |c| [c.name, c.id] }, params[:category]),
          { include_blank: "All categories" },
          data: { action: "change->auto-submit#submit" } %>
      </div>

      <div class="filter-section">
        <h3>Brand</h3>
        <%= f.select :brand,
          options_for_select(@brands.map { |b| [b.name, b.id] }, params[:brand]),
          { include_blank: "All brands" },
          data: { action: "change->auto-submit#submit" } %>
      </div>

      <div class="filter-section">
        <h3>Price range</h3>
        <div class="price-range">
          <%= f.number_field :price_min, value: params[:price_min], placeholder: "Min", min: 0,
            data: { action: "change->auto-submit#submit" } %>
          <span>&ndash;</span>
          <%= f.number_field :price_max, value: params[:price_max], placeholder: "Max", min: 0,
            data: { action: "change->auto-submit#submit" } %>
        </div>
      </div>

      <div class="filter-actions">
        <%= f.submit "Apply", class: "btn btn-primary" %>
        <% if @active_filters_count > 0 %>
          <%= link_to "Clear all (#{@active_filters_count})", products_path, class: "btn btn-secondary" %>
        <% end %>
      </div>
    <% end %>
  </aside>

  <%# Results frame includes product grid AND pagination %>
  <main class="catalog-results">
    <%= turbo_frame_tag "products_results" do %>
      <div class="results-toolbar">
        <p><%= pluralize(@pagy.count, "product") %> found</p>

        <%= form_with url: products_path, method: :get, data: {
          turbo_frame: "products_results",
          controller: "auto-submit"
        } do |f| %>
          <%# Carry forward current filters as hidden fields %>
          <% %i[q category brand price_min price_max].each do |key| %>
            <% if params[key].present? %>
              <%= f.hidden_field key, value: params[key] %>
            <% end %>
          <% end %>

          <%= f.select :sort,
            options_for_select([
              ["Featured", "featured"], ["Newest", "newest"],
              ["Price: Low to High", "price_asc"], ["Price: High to Low", "price_desc"],
              ["Best Selling", "best_selling"]
            ], params[:sort] || "featured"),
            {}, data: { action: "change->auto-submit#submit" } %>
        <% end %>
      </div>

      <% if @products.any? %>
        <div class="products-grid">
          <%= render partial: "products/product_card", collection: @products, as: :product %>
        </div>
        <nav class="pagination" aria-label="Product pagination">
          <%== pagy_nav(@pagy) %>
        </nav>
      <% else %>
        <div class="empty-state">
          <h3>No products found</h3>
          <%= link_to "Clear all filters", products_path, class: "btn btn-primary" %>
        </div>
      <% end %>
    <% end %>
  </main>
</div>
```

### Auto-Submit Controller

```javascript
// app/javascript/controllers/auto_submit_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { delay: { type: Number, default: 300 } }

  submit() {
    clearTimeout(this.timeout)
    this.timeout = setTimeout(() => {
      this.element.requestSubmit()
    }, this.delayValue)
  }
}
```

### Why This Works

- **Sidebar outside the frame.** The filter form targets `products_results` via `data-turbo-frame`, so it persists while only the results grid updates.
- **Sort preserves filters.** The sort form carries forward all current filter params as hidden fields, preventing filter loss on sort change.
- **Debounced auto-submit.** The Stimulus controller debounces input events (300ms default) before submitting, avoiding excessive requests during typing.
- **Pagination inside the frame.** Both the product grid and Pagy navigation live inside the Turbo Frame, so clicking page links updates results without a full page reload.
- **Canonical URL state.** All filter and sort state lives in query parameters, making results bookmarkable and back/forward-friendly.
