# Databricks notebook - matching.py
# Purpose: create candidate pairs (blocking) and compute similarity scores for asset records
# Note: This is a scalable example using blocking keys and UDF similarity (Jaro-Winkler).
# For very large corpora, use approximate nearest neighbor libraries or Spark ML techniques.

from pyspark.sql import SparkSession
from pyspark.sql.functions import col, concat_ws, substring, when, lit, current_timestamp
from pyspark.sql import functions as F
from pyspark.sql.types import DoubleType
import pyspark.sql.types as T

spark = SparkSession.builder.getOrCreate()

storage_account = dbutils.secrets.get(scope="mdm", key="adls_account")
container = "datalake"
silver_delta = f"abfss://{container}@{storage_account}.dfs.core.windows.net/silver/assets_standardized/"
matching_delta = f"abfss://{container}@{storage_account}.dfs.core.windows.net/mdm_matches/"

df = spark.read.format("delta").load(silver_delta)

# Blocking key: first 6 chars of normalized name + first 2 chars of ISIN (if present)
df = df.withColumn("block_key", concat_ws("_", substring(col("name_norm"),1,6), substring(col("isin"),1,2)))

# Self-join on block_key to produce candidate pairs
pairs = df.alias("a").join(df.alias("b"), on=col("a.block_key") == col("b.block_key")) \
    .where(col("a.ingest_time") <= col("b.ingest_time")) \
    .select(
        col("a.*").alias("a"),
        col("b.*").alias("b")
    )

# UDF for Jaro-Winkler (simple implementation or use python library)
from jellyfish import jaro_winkler

def jw(s1, s2):
    if s1 is None or s2 is None:
        return 0.0
    return float(jaro_winkler(s1, s2))

jw_udf = F.udf(jw, DoubleType())

pairs = pairs.withColumn("name_sim", jw_udf(F.col("a.name_norm"), F.col("b.name_norm")))
pairs = pairs.withColumn("isin_match", when((F.col("a.isin").isNotNull()) & (F.col("a.isin")==F.col("b.isin")), 1.0).otherwise(0.0))
pairs = pairs.withColumn("overall_score", 0.7*F.col("name_sim") + 0.3*F.col("isin_match"))

# Filter candidate pairs above threshold
matched_pairs = pairs.where(F.col("overall_score") >= 0.85) \
    .select(
        F.col("a.*").alias("left_"),
        F.col("b.*").alias("right_"),
        F.col("overall_score"),
        F.current_timestamp().alias("match_ts")
    )

# Persist matches
(
    matched_pairs.write
    .format("delta")
    .mode("overwrite")
    .option("mergeSchema", "true")
    .save(matching_delta)
)

print("Wrote match candidates to:", matching_delta)
