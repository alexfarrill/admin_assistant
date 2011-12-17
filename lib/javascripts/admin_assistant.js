/******************************************************************************
Don't edit this file: It gets re-copied every time the server starts.
******************************************************************************/

var AA = AA || {};

// Autocompleter
if (AA.autocomplete_source) $("#search").autocomplete({ source: AA.autocomplete_source, select: function(e, ui) { $("form#search_form").submit(); } });

$.fn.record_id = function() {
  return this.parents("[data-record-id]").attr("data-record-id")
}