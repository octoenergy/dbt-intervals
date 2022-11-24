{% macro intervals_overlap(below, above) %}
  {{ merged_interval_below(below) }} < {{ merged_interval_above(above) }}
{% endmacro %}
