-- TRADER SENTIMENT ANALYSIS — SQL QUERIES
-- Dataset: Hyperliquid Trades × Bitcoin Fear & Greed Index

-- NOTE: These queries assume two tables:
--   trades  → historical_data.csv
--   sentiment → fear_greed_index.csv
-- Joined on Date for all cross-table queries.

-- SECTION 1: BASIC EXPLORATION
-- 1.1 Total trades, unique accounts, unique coins
SELECT
    COUNT(*)                    AS total_trades,
    COUNT(DISTINCT account)     AS unique_traders,
    COUNT(DISTINCT coin)        AS unique_coins,
    MIN(date)                   AS earliest_trade,
    MAX(date)                   AS latest_trade
FROM trades;


-- 1.2 Trade volume by side (BUY vs SELL)
SELECT
    side,
    COUNT(*)                        AS trade_count,
    ROUND(AVG(size_usd), 2)         AS avg_size_usd,
    ROUND(SUM(size_usd), 2)         AS total_volume_usd
FROM trades
GROUP BY side
ORDER BY trade_count DESC;


-- 1.3 Top 10 most traded coins
SELECT
    coin,
    COUNT(*)                    AS trade_count,
    ROUND(SUM(size_usd), 2)     AS total_volume_usd,
    ROUND(AVG(closed_pnl), 4)   AS avg_pnl
FROM trades
GROUP BY coin
ORDER BY trade_count DESC
LIMIT 10;

-- SECTION 2: SENTIMENT ANALYSIS
-- 2.1 Average PnL by sentiment classification
SELECT
    s.classification                        AS sentiment,
    COUNT(t.account)                        AS total_trades,
    ROUND(AVG(t.closed_pnl), 2)            AS avg_pnl,
    ROUND(SUM(t.closed_pnl), 2)            AS total_pnl,
    ROUND(AVG(t.size_usd), 2)              AS avg_trade_size
FROM trades t
JOIN sentiment s ON t.date = s.date
GROUP BY s.classification
ORDER BY avg_pnl DESC;


-- 2.2 Win rate by sentiment (closed trades only)
SELECT
    s.classification                                    AS sentiment,
    COUNT(*)                                            AS closed_trades,
    SUM(CASE WHEN t.closed_pnl > 0 THEN 1 ELSE 0 END) AS winning_trades,
    ROUND(
        100.0 * SUM(CASE WHEN t.closed_pnl > 0 THEN 1 ELSE 0 END) / COUNT(*), 2
    )                                                   AS win_rate_pct
FROM trades t
JOIN sentiment s ON t.date = s.date
WHERE t.closed_pnl != 0
GROUP BY s.classification
ORDER BY win_rate_pct DESC;


-- 2.3 Buy vs Sell behaviour by sentiment
SELECT
    s.classification            AS sentiment,
    t.side,
    COUNT(*)                    AS trade_count,
    ROUND(
        100.0 * COUNT(*) /
        SUM(COUNT(*)) OVER (PARTITION BY s.classification), 2
    )                           AS pct_of_sentiment
FROM trades t
JOIN sentiment s ON t.date = s.date
GROUP BY s.classification, t.side
ORDER BY s.classification, t.side;

-- SECTION 3: TRADER PERFORMANCE
-- 3.1 Top 10 traders by total PnL
SELECT
    account,
    COUNT(*)                                            AS total_trades,
    ROUND(SUM(closed_pnl), 2)                          AS total_pnl,
    ROUND(AVG(closed_pnl), 4)                          AS avg_pnl_per_trade,
    ROUND(
        100.0 * SUM(CASE WHEN closed_pnl > 0 THEN 1 ELSE 0 END)
        / NULLIF(SUM(CASE WHEN closed_pnl != 0 THEN 1 ELSE 0 END), 0), 2
    )                                                   AS win_rate_pct
FROM trades
WHERE closed_pnl != 0
GROUP BY account
ORDER BY total_pnl DESC
LIMIT 10;


-- 3.2 Contrarian traders — top performers during FEAR markets
SELECT
    t.account,
    COUNT(*)                                            AS fear_trades,
    ROUND(SUM(t.closed_pnl), 2)                        AS fear_pnl,
    ROUND(
        100.0 * SUM(CASE WHEN t.closed_pnl > 0 THEN 1 ELSE 0 END) / COUNT(*), 2
    )                                                   AS fear_win_rate_pct
FROM trades t
JOIN sentiment s ON t.date = s.date
WHERE s.classification IN ('Fear', 'Extreme Fear')
  AND t.closed_pnl != 0
GROUP BY t.account
HAVING COUNT(*) >= 20
ORDER BY fear_pnl DESC
LIMIT 10;


-- 3.3 Trader performance across different sentiment conditions
SELECT
    t.account,
    s.classification                                    AS sentiment,
    COUNT(*)                                            AS trades,
    ROUND(SUM(t.closed_pnl), 2)                        AS total_pnl,
    ROUND(AVG(t.size_usd), 2)                          AS avg_size
FROM trades t
JOIN sentiment s ON t.date = s.date
WHERE t.closed_pnl != 0
GROUP BY t.account, s.classification
ORDER BY total_pnl DESC
LIMIT 20;

-- SECTION 4: COIN-LEVEL INSIGHTS
-- 4.1 Coin performance by sentiment
SELECT
    t.coin,
    s.classification                    AS sentiment,
    COUNT(*)                            AS trades,
    ROUND(AVG(t.closed_pnl), 2)        AS avg_pnl,
    ROUND(SUM(t.closed_pnl), 2)        AS total_pnl
FROM trades t
JOIN sentiment s ON t.date = s.date
WHERE t.closed_pnl != 0
  AND t.coin IN ('HYPE', 'BTC', 'ETH', 'SOL', 'FARTCOIN', '@107')
GROUP BY t.coin, s.classification
ORDER BY t.coin, avg_pnl DESC;


-- 4.2 Most profitable coin per sentiment
SELECT
    sentiment,
    coin,
    avg_pnl
FROM (
    SELECT
        s.classification                AS sentiment,
        t.coin,
        ROUND(AVG(t.closed_pnl), 2)    AS avg_pnl,
        RANK() OVER (
            PARTITION BY s.classification
            ORDER BY AVG(t.closed_pnl) DESC
        )                               AS rnk
    FROM trades t
    JOIN sentiment s ON t.date = s.date
    WHERE t.closed_pnl != 0
    GROUP BY s.classification, t.coin
) ranked
WHERE rnk = 1
ORDER BY avg_pnl DESC;

-- SECTION 5: TIME-BASED PATTERNS
-- 5.1 Daily trading activity summary
SELECT
    t.date,
    s.classification                                    AS sentiment,
    s.value                                             AS fg_value,
    COUNT(*)                                            AS trades,
    ROUND(AVG(t.closed_pnl), 2)                        AS avg_pnl,
    ROUND(SUM(t.closed_pnl), 2)                        AS total_pnl,
    ROUND(AVG(t.size_usd), 2)                          AS avg_size_usd
FROM trades t
JOIN sentiment s ON t.date = s.date
GROUP BY t.date, s.classification, s.value
ORDER BY t.date;


-- 5.2 Monthly PnL trend by sentiment
SELECT
    STRFTIME('%Y-%m', t.date)          AS month,
    s.classification                    AS sentiment,
    COUNT(*)                            AS trades,
    ROUND(SUM(t.closed_pnl), 2)        AS monthly_pnl
FROM trades t
JOIN sentiment s ON t.date = s.date
WHERE t.closed_pnl != 0
GROUP BY month, s.classification
ORDER BY month, monthly_pnl DESC;

-- SECTION 6: ADVANCED METRICS
-- 6.1 Sharpe-style ratio by sentiment (avg pnl / std pnl)
SELECT
    s.classification                            AS sentiment,
    ROUND(AVG(t.closed_pnl), 4)                AS avg_pnl,
    ROUND(
        AVG(t.closed_pnl) /
        NULLIF(
            SQRT(AVG(t.closed_pnl * t.closed_pnl) - AVG(t.closed_pnl) * AVG(t.closed_pnl)),
            0
        ), 4
    )                                           AS sharpe_ratio
FROM trades t
JOIN sentiment s ON t.date = s.date
WHERE t.closed_pnl != 0
GROUP BY s.classification
ORDER BY sharpe_ratio DESC;


-- 6.2 Fee analysis by sentiment
SELECT
    s.classification                    AS sentiment,
    ROUND(AVG(t.fee), 4)               AS avg_fee,
    ROUND(SUM(t.fee), 2)               AS total_fees_paid,
    ROUND(AVG(t.fee / NULLIF(t.size_usd, 0)) * 100, 4) AS fee_pct_of_trade
FROM trades t
JOIN sentiment s ON t.date = s.date
GROUP BY s.classification
ORDER BY avg_fee DESC;