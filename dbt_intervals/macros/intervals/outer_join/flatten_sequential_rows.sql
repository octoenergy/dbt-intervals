/* MACRO - Flatten Sequential Interval Rows in Table */
{% macro flatten_sequential_rows(
    table,
    grouping_columns,
    interval_start_column,
    interval_end_column,
    exclude_value_columns=[]
  ) %}

{% set value_columns = dbt_utils.star(from=table, except=grouping_columns+[interval_start_column,interval_end_column] + exclude_value_columns).split(',') %}

/*
 This macro is used to combine sequential interval rows where values match.
 For reference see https://bertwagner.com/posts/gaps-and-islands/

 'exclude_value_columns' should be a list of all columns where the value is unique to that row but
 are not important when grouping rows - e.g. row updated timestamps - these will be omitted from
 the resulting combined dataset.)
 */
SELECT {{ concat_affix(
        grouping_columns,
        ','
      ) }},
       {{ concat_affix(
        value_columns,
        ','
      ) }},
       MIN(StartDate) AS {{ interval_start_column }},
       MAX(EndDate)   AS {{ interval_end_column }}
FROM (
         SELECT *,
                SUM(CASE
                        WHEN Groups.PreviousEndDate >= StartDate AND
                             Groups.value_array = ARRAY({{ concat_affix(
        value_columns,
        ','
      ) }})
                            THEN 0
                        ELSE 1 END) OVER (PARTITION BY {{ concat_affix(
        grouping_columns,
        ','
      ) }} ORDER BY Groups.RN) AS IslandId
         FROM (
                  SELECT tbl.*,
                         ROW_NUMBER()
                                 OVER (PARTITION BY {{ concat_affix(
        grouping_columns,
        ','
      ) }} ORDER BY {{ concat_affix(
        grouping_columns,
        ','
      ) }}, {{ interval_start_column }},{{ interval_end_column }})                                                            AS RN,
                         {{ interval_start_column }}                                                                          as StartDate,
                         {{ interval_end_column }}                                                                            as EndDate,
                         LAG({{ interval_end_column }}, 1)
                             OVER (PARTITION BY {{ concat_affix(
        grouping_columns,
        ','
      ) }} ORDER BY {{ interval_start_column }}, {{ interval_end_column }}) AS PreviousEndDate,
                         LAG(ARRAY({{ concat_affix(
        value_columns,
        ','
      ) }}), 1)
                             OVER (PARTITION BY {{ concat_affix(
        grouping_columns,
        ','
      ) }} ORDER BY {{ interval_start_column }}, {{ interval_end_column }}) AS value_array
                  FROM {{ table }} tbl
                  ORDER BY {{ concat_affix(
        grouping_columns,
        ','
      ) }}, {{ interval_start_column }}, {{ interval_end_column }}
              ) Groups
         ORDER BY {{ concat_affix(
        grouping_columns,
        ','
      ) }}, {{ interval_start_column }}, {{ interval_end_column }}
     ) Islands
GROUP BY {{ concat_affix(
        grouping_columns,
        ','
      ) }},
         {{ concat_affix(
        value_columns,
        ','
      ) }},
         IslandId
ORDER BY {{ concat_affix(
        grouping_columns,
        ','
      ) }},
         {{ interval_start_column }}
{% endmacro %}