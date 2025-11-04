# Databricks notebook - write_golden.py
# Purpose: MERGE golden candidates into final asset_golden Delta table with audit logging

from pyspark.sql import SparkSession
from pyspark.sql.functions import current_timestamp
spark = SparkSession.builder.getOrCreate()

storage_account = dbutils.secrets.get(scope="mdm", key="adls_account")
container = "datalake"
gold_delta = f"abfss://{container}@{storage_account}.dfs.core.windows.net/gold/asset_golden/"
gold_candidates = f"abfss://{container}@{storage_account}.dfs.core.windows.net/gold/temp_golden_candidates/"

candidates_df = spark.read.format("delta").load(gold_candidates)

# MERGE into asset_golden using business key (e.g., composite of identifiers or generated id)
from delta.tables import DeltaTable

try:
    target = DeltaTable.forPath(spark, gold_delta)
    (target.alias("t")
     .merge(candidates_df.alias("s"), "t.isin = s.isin OR (t.ticker = s.ticker AND t.issuer = s.issuer)")
     .whenMatchedUpdate(set={
         "name": "s.name",
         "legal_name": "s.legal_name",
         "record_update_ts": "current_timestamp()",
         "record_version": "t.record_version + 1",
         "match_confidence": "s.match_confidence",
         "provenance": "struct(array_union(t.provenance.last_sources, array(s.record_source)), current_timestamp())"
     })
     .whenNotMatchedInsert(values={
         "asset_id": "s.asset_id",
         "name": "s.name",
         "legal_name": "s.legal_name",
         "asset_type": "s.asset_type",
         "isin": "s.isin",
         "cusip": "s.cusip",
         "sedol": "s.sedol",
         "ticker": "s.ticker",
         "issuer": "s.issuer",
         "country_of_issue": "s.country_of_issue",
         "currency": "s.currency",
         "maturity_date": "s.maturity_date",
         "attributes": "s.attributes",
         "record_source": "s.record_source",
         "record_create_ts": "current_timestamp()",
         "record_update_ts": "current_timestamp()",
         "record_version": "1",
         "match_confidence": "s.match_confidence",
         "provenance": "struct(array(s.record_source), current_timestamp())"
     })
     .execute()
    )
    print("Merge completed")
except Exception as e:
    # First-time create
    candidates_df.write.format("delta").mode("overwrite").save(gold_delta)
    print("Created gold table")
