/* MACRO - Sequentialize Interval Table */
{% macro sequentialize_table(
    table,
    grouping_columns,
    interval_start_column,
    interval_end_column,
    validation_columns,
    flag_overlaps_column_name = None
  ) %}

{% set value_columns = dbt_utils.star(from=table, except=grouping_columns+[interval_start_column,interval_end_column]).split(',') %}

  -- Get the interval start & end date columns filtering out instances where start >= end
  WITH interval_points_wide AS (
    SELECT
      {{ concat_affix(
        grouping_columns,
        ','
      ) }},
      {{ interval_start_column }} AS interval_start,
      {{ interval_end_column }} AS interval_end
    FROM
      {{ table }}
    --TODO Change this to an error raise rather than filtering out silently - breaking change!
    WHERE {{ interval_start_column }} < COALESCE(
      {{ interval_end_column }}, {{ var('distant_future_timestamp') }}
    )
  ),
  -- Stack them into a single column and remove duplicates to get distinct intervals where values may differ
  interval_points_tall AS (
    SELECT
      DISTINCT {{ concat_affix(
        grouping_columns,
        ','
      ) }},
      interval_start AS interval_point
    FROM
      interval_points_wide
    UNION
    SELECT
      DISTINCT {{ concat_affix(
        grouping_columns,
        ','
      ) }},
      interval_end AS interval_point
    FROM
      interval_points_wide
  ),
  -- Convert to interval rows by taking the next rows interval point value as the end timestamp of the preceding row
  interval_points AS (
    SELECT
      {{ concat_affix(
        grouping_columns,
        ','
      ) }},
      interval_point AS interval_start,
      LEAD(interval_point, 1) OVER by_group_asc AS interval_end
    FROM
      interval_points_tall
    QUALIFY RANK() over by_group_desc != 1
    WINDOW
      by_group_asc AS (
        PARTITION BY {{ concat_affix(grouping_columns, ',') }} ORDER BY interval_point ASC NULLS LAST),
      by_group_desc AS (
        PARTITION BY {{ concat_affix(grouping_columns, ',') }} ORDER BY interval_point DESC NULLS FIRST
      )
  ) -- Join the original table back onto your interval dataset and use a validation function to drop duplicates.
  -- In this example we will use the latest id to filter on most recent agreements where there are overlaps.
SELECT
  {{ concat_affix(
    grouping_columns,
    delim = ',',
    prefix = 'ip.'
  ) }},
  ip.interval_start AS {{ interval_start_column }},
  ip.interval_end AS {{ interval_end_column }},
  {% for value_col in value_columns %}
    MAX_BY(
      tbl.{{ value_col }},(
      {{ concat_affix(
        validation_columns,
        delim = ','
      ) }})
    ) AS {{ value_col }}

    {% if not loop.last %},
    {% endif %}
  {% endfor %}

  {% if flag_overlaps_column_name %},
    CASE
      WHEN COUNT(
        ip.interval_start
      ) > 1 THEN TRUE
      ELSE FALSE
    END AS {{ flag_overlaps_column_name }}
  {% endif %}
FROM
  interval_points ip
  LEFT JOIN {{ table }} tbl
  ON {% for grouping_col in grouping_columns %}
    tbl.{{ grouping_col }} = ip.{{ grouping_col }}

    {% if not loop.last %}
      AND
    {% endif %}
  {% endfor %}
  AND {{ intervals_overlap(
    below=["tbl." + interval_start_column, "ip.interval_start"],
    above=[
      "COALESCE(tbl." + interval_end_column + ", " + var("distant_future_timestamp") + ")",
      "COALESCE(ip.interval_end, " + var("distant_future_timestamp") + ")",
    ]
  ) }}
WHERE
  {{ concat_affix(
    grouping_columns,
    delim = ' AND ',
    prefix = 'tbl.',
    suffix = ' IS NOT NULL'
  ) }}
  AND tbl.{{ interval_start_column }} < COALESCE(tbl.{{ interval_end_column }}, {{var('distant_future_timestamp')}})
GROUP BY
  {{ concat_affix(
    grouping_columns,
    delim = ',',
    prefix = 'ip.'
  ) }},
  ip.interval_start,
  ip.interval_end
ORDER BY
  {{ concat_affix(
    grouping_columns,
    delim = ',',
    prefix = 'ip.'
  ) }},
  ip.interval_start,
  ip.interval_end
{% endmacro %}
