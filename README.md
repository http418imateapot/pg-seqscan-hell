# 資料庫索引品質分析小工具

---

## 目的

提供 PostgreSQL 資料表索引品質分析與測試資料 SQL 範例，首先分析關聯式資料庫中的低效索引特徵，包括使用率、Dead Tuples、Index/Table Size 比例，分析辨識未命中索引 (Index Miss) 與過度索引 (Over-indexing)，用於改善查詢效能並減少儲存空間浪費。

## 目標

找出品質不良的索引，調整資料表設計後可改善：

* 儲存空間浪費：找出過大或冗餘的索引，刪除不必要的索引。
* 提升查詢效能：找出未被使用的索引，或查詢未能利用的索引，進行重新設計。
* 最佳化索引策略：透過排序與指標分析，協助資料庫管理員 調整索引，提升資料表查詢效率。

## 低效索引特徵

以下依索引品質嚴重程度，由高到低介紹低校索引的特徵與定義。

### 索引超過資料表大小 (index_over_table_size)

* 計算公式：``(index_size_bytes - table_size_bytes) / table_size_bytes``
* 定義：衡量索引相較於資料表的大小是否過大。
* 糟糕的索引設計：當 index_over_table_size > 100%，表示該索引比資料表本身還大，可能是 儲存空間的浪費。過大的索引會導致寫入變慢，並影響查詢效能。


### 全表掃描 (seq_scan_count)

* 定義：統計資料表在查詢時 未使用索引，而直接執行全表掃描 的次數。
* 糟糕的索引設計：若 seq_scan_count 很高，但 index_usage_count 很低，代表該查詢可能缺少適當的索引。既有索引可能設計不良，導致查詢無法使用。或是查詢可能沒有寫好，導致索引無法發揮作用。

### 索引佔表比例 (index_table_ratio)

* 計算公式：``index_size_bytes / table_size_bytes``
* 定義：計算索引大小與資料表大小的比例。
* 糟糕的索引設計：當 index_table_ratio > 100%，代表索引大小已經超過資料表本身，可能有過度索引 (over-indexing) 的問題。過多索引不僅浪費儲存，也可能降低寫入效能，因為每次新增或修改資料時，索引也需要同步更新。

### 死亡元組 (dead tuples)

* 定義：dead tuples 是 已刪除或更新但尚未被 VACUUM 清理的記錄，仍然佔用索引與表的空間。
* 糟糕的索引設計：若索引 index scan 很少使用，但 dead tuple 比例很高，代表索引可能已經失去作用，應進行重建 (REINDEX) 或刪除。
若 dead_tuple_size_estimate > 500MB，應該執行 VACUUM FULL 或 REINDEX 來回收空間。

### 資料表大小 (table_size_bytes)

* 糟糕的索引設計：大表的索引若使用率低，可能導致查詢效能下降。小表的索引若過大，則可能是空間浪費。

## 使用說明

以下步驟說明如何使用提供的 SQL 檔案來測試索引品質分析：

(測試資料會建立並使用 schema "``bad_index_test``")

1. **建立測試資料**：執行 `sql/create_test_data.sql` 建立測試資料表與索引，並插入測試資料。
2. **索引品質分析**：執行 `sql/pg_index_check.sql` 分析資料表索引品質，找出低效索引。
3. **清理測試資料**：執行 `sql/cleanup_test_data.sql` 清理測試資料表與索引。

### 測試資料說明

測試資料表 `test_orders` 包含以下欄位：
- `id`: 主鍵
- `user_id`: 使用者 ID
- `order_date`: 訂單日期
- `amount`: 訂單金額
- `status`: 訂單狀態 (pending, shipped, delivered, cancelled)
- `random_value`: 隨機值 (模擬無用索引)

建立以下索引：
- `idx_order_date`: 訂單日期索引
- `idx_user_id`: 使用者 ID 索引
- `idx_random`: 隨機值索引 (可能無用)
- `idx_status`: 訂單狀態索引 (可能無用)
- `idx_amount`: 訂單金額索引 (過度索引範例)

### 分析結果簡介

以下為索引品質分析結果範例：

| Schema          | Table       | Index         | Table Size | Index Size | Seq Scan Count | Index Usage Count | Dead Tuple Ratio | Dead Tuple Size | Index/Table Ratio | Index Over Table Size |
|-----------------|-------------|---------------|------------|------------|----------------|-------------------|------------------|-----------------|-------------------|-----------------------|
| bad_index_test  | test_orders | idx_random    | 21 MB      | 11 MB      | 15             | 0                 | 28.21            | 5929 kB         | 54.97             | -45.03                |
| bad_index_test  | test_orders | idx_amount    | 21 MB      | 5944 kB    | 15             | 1                 | 28.21            | 5929 kB         | 28.28             | -71.72                |
| bad_index_test  | test_orders | idx_order_date| 21 MB      | 4760 kB    | 15             | 1                 | 28.21            | 5929 kB         | 22.65             | -77.35                |
| bad_index_test  | test_orders | test_orders_pkey | 21 MB   | 4408 kB    | 15             | 0                 | 28.21            | 5929 kB         | 20.97             | -79.03                |
| bad_index_test  | test_orders | idx_user_id   | 21 MB      | 2056 kB    | 15             | 1                 | 28.21            | 5929 kB         | 9.78              | -90.22                |
| bad_index_test  | test_orders | idx_status    | 21 MB      | 1544 kB    | 15             | 1                 | 28.21            | 5929 kB         | 7.35              | -92.65                |

透過分析結果，可以辨識出低效索引，進而進行調整以提升查詢效能並減少儲存空間浪費。

