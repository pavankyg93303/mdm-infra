```text
ADLS Gen2 recommended layout (Delta / Medallion)

/datalake/
  /bronze/
    /assets_raw/
      /sourceA/yyyy/MM/dd/*.csv
      /sourceB/yyyy/MM/dd/*.json
  /silver/
    /assets_standardized/
      year=2025/month=11/day=04/ (Delta partitions)
  /gold/
    /asset_golden/           (Delta table)
      year=2025/month=11/ (partition by asset_type or country)
  /mdm_metadata/
    /survivorship_rules.json
    /source_priorities.csv
    /audit/
      merges/
  /logs/
    /ingest/
    /jobs/
```
