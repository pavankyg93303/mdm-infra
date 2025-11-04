```text
# Asset Management MDM Solution (Azure) — Overview

Summary
- Goal: Create a reliable golden record for financial assets (securities, funds, derivatives, real estate assets, etc.) using Delta Lake, Databricks (PySpark), ADF orchestration, Synapse for serving/analytics.
- Architecture: Medallion (Bronze → Silver → Gold) in ADLS Gen2 with Delta tables. Ingestion with ADF copy or Databricks batch jobs. Matching & survivorship implemented in Databricks using PySpark; golden records stored as Delta Lake tables consumed via Synapse or Power BI.
- Key components:
  - Azure Data Lake Storage Gen2: landing zones and Delta tables
  - Azure Data Factory: orchestrate ingestion, Databricks notebook jobs, Synapse refreshes
  - Azure Databricks: PySpark notebooks for standardization, deduping/matching, survivorship, merging
  - Delta Lake: versioning, time-travel, ACID (MERGE)
  - Azure Synapse Workspace: external tables / serving layer
  - Azure Key Vault & Managed Identities for secrets and secure access
  - Monitoring: Azure Monitor/Log Analytics, Databricks job metrics, ADF run logs

Primary Data Flow
1. Source systems (Custody, OMS, Pricing vendors, Reference data providers) export files/messages to staging endpoints (SFTP, APIs, Kafka).
2. ADF copies raw files into ADLS Gen2 /bronze/ (or triggers Databricks ingestion) — keep raw as-is (schema on read).
3. Databricks ingestion notebook transforms raw into normalized Bronze Delta tables (light cleaning, schema extraction).
4. Standardization (Silver) notebook normalizes names, identifiers (ISIN / CUSIP / SEDOL), asset types, currency conversions, date/time, legal entity IDs. Stores to /silver/.
5. Matching & Linkage: blocking + similarity scoring to find records referring to same physical asset across sources. Output: match groups and candidate pairs.
6. Survivorship: rules-based (source priority, completeness, recency, trust score) to pick attribute values for golden record.
7. Golden record persisted to /gold/ as Delta table; audit log of merges and lineage stored.
8. Synapse or Databricks SQL serves golden records for downstream analytics and operational systems.

MDM Data Model (example asset_golden)
- asset_id (UUID) — MDM unique id
- source_ids: map of {source:source_asset_id} or separate relation
- identifiers: isin, cusip, sedol, ticker
- name, legal_name, asset_type (ENUM), sector, issuer, currency, country_of_issue
- share_class, coupon, maturity_date (for fixed income)
- status, lifecycle_dates
- attributes JSON (freeform for vendor-specific)
- record_source, record_create_ts, record_update_ts, record_version
- provenance: last_match_sources, match_confidence, survivorship_reason

Operational & Governance Highlights
- Survive rules kept in Delta table or JSON configuration (policy-driven).
- Audit table capturing every MERGE (old values, new values, timestamp, user/system).
- Source trust/priority table configurable per domain.
- Data lineage via tags and metadata (recommend Azure Purview integration).
- Reprocessing support by time-travel and vacuum policies.

SLA & Performance
- Size planning: partition gold by asset_type or country; use Z-order for common predicates.
- Batch windows: nightly full reconcile; near-real-time with micro-batches if needed.
- Use Databricks clusters autocreate + pools for cost control.

Security & Compliance
- ADLS encryption at rest (managed keys), network restrictions (private endpoints)
- Databricks workspace in VNet (No Public IP), cluster with AAD passthrough / credential passthrough
- Key Vault for secrets, ADF and Databricks use Managed Identity
- RBAC for dataset and table-level access; Synapse-managed identity for reads

CI/CD
- Store notebooks in Git repos (Databricks Repos or GitHub).
- ADF ARM template export/import for pipeline deployment.
- Terraform/ARM for ADLS, Databricks workspace, Synapse objects.

Contact/Notes
- This repo contains example notebooks and pipeline JSON with placeholders; parameterize before deploying.
```
