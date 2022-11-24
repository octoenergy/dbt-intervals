{% macro merged_interval_below(below, extend_back=False, id_col=none, primary_below=none) %}
  {% if extend_back %}
    CASE
      WHEN ROW_NUMBER() OVER (PARTITION BY {{ id_col }} ORDER BY GREATEST({{ concat_affix(below) }})) = 1
        THEN {{ primary_below }}
      ELSE GREATEST({{ concat_affix(below) }})
    END
  {% else %}
    GREATEST({{ concat_affix(below) }})
  {% endif %}
{% endmacro %}
