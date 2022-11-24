{% macro merged_interval_above(above) %}
  LEAST({{ concat_affix(above) }})
{% endmacro %}
