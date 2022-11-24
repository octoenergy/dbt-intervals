{% docs intervals_overlap %}
This macro checks that several intervals overlap, returning a SQL expression evaluating to a
boolean.
{% enddocs %}

{% docs merged_interval_above %}
This macro returns the upper end of the overlapping interval that is covered by _all_ of the input
intervals.
{% enddocs %}

{% docs merged_interval_below %}
This macro returns the lower end of the overlapping interval that is covered by _all_ of the input
intervals.

Due to the `first_snapshot_from_created_at` macro, which artificially extends snapshot
columns backwards to fill in missing data, sometimes there are cases where relationships in one
snapshot table don't exist in another snapshot table. In those cases, the `extend_back` argument
combined with the `primary_below` and `id_col` arguments allows for extending the overlapping
interval backwards to be equal to one of the input columns interval starts. Similarly to
`first_snapshot_from_created_at`, this corresponds to us not knowing what the true value in that
period was, but taking the next value that we _do_ know as a good enough guess.
{% enddocs %}
