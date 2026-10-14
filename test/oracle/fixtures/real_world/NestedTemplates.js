this.$('.pagination').html(`
  <div class="text-center pad-v ">
      <div class="text-gray-dark margin-bottom-half">
          ${this.collection.length} ${this.collection.model.modelName.plural.titleize()}
          Loaded of
          <span class="js-total">...</span>
      </div>
      <div class="js-more-action relative">
          <button type="button" class="js-more uniformButton">Load More</button>
          <span class="margin-left">
              Load By
          </span>
          <select class="js-per-page">
              ${_.map([25, 50, 100], v => `<option ${this.collection.cursor.get('per_page') == v ? 'selected' : ''}>${v}</option>`).join()}
          </select>
      </div>
  </div>
`);
