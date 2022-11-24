{% macro is_currently_active_record(valid_from, valid_to) %}
  {{ date_between('NOW()', valid_from, valid_to) }}
{% endmacro %}
