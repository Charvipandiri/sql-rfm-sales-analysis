SELECT * FROM sales_data_sample;

-- Which product line generates the highest sales? 
SELECT PRODUCTLINE, 
       sum(sales) as total_sales
FROM sales_data_sample
GROUP BY PRODUCTLINE
ORDER BY  total_sales DESC LIMIT 1;


-- Which year had the highest sales?
SELECT  YEAR_ID, 
		SUM(sales) AS total_sales
FROM sales_data_sample
GROUP BY YEAR_ID
ORDER BY total_sales DESC limit 1 ; 


-- Which deal size contributes the most revenue?
SELECT DEALSIZE,
       SUM(sales) AS total_sales
FROM sales_data_sample
GROUP BY DEALSIZE
ORDER BY  total_sales  DESC;

-- What is the best product in United States?
select country, YEAR_ID, PRODUCTLINE, sum(sales) Revenue
from sales_data_sample
where country = 'USA'
group by  country, YEAR_ID, PRODUCTLINE
order by 4 desc;

-- Which month is the best month for sales in each year?
WITH sales_year AS (
    SELECT
        YEAR_ID,
        MONTH_ID,
        SUM(SALES) AS total_sales
    FROM sales_data_sample
    WHERE MONTH_ID IS NOT NULL
    GROUP BY YEAR_ID, MONTH_ID
),

sales_rank AS (
    SELECT
        YEAR_ID,
        MONTH_ID,
        total_sales,
        RANK() OVER (
            PARTITION BY YEAR_ID
            ORDER BY total_sales DESC
        ) AS rank_no
    FROM sales_year
)

SELECT
    YEAR_ID,
    MONTH_ID,
    total_sales
FROM sales_rank
WHERE rank_no = 1
ORDER BY YEAR_ID;


-- During the best sales month, which product line sells the most?
WITH monthly_sales AS
(
    SELECT
        YEAR_ID,
        MONTH_ID,
        SUM(SALES) AS total_sales
    FROM sales_data_sample
    GROUP BY YEAR_ID, MONTH_ID
),

best_month AS
(
    SELECT
        YEAR_ID,
        MONTH_ID
    FROM monthly_sales
    ORDER BY total_sales DESC
    LIMIT 1
)

SELECT
    s.PRODUCTLINE,
    SUM(s.SALES) AS total_sales
FROM sales_data_sample s
JOIN best_month bm
    ON s.YEAR_ID = bm.YEAR_ID
   AND s.MONTH_ID = bm.MONTH_ID
GROUP BY s.PRODUCTLINE
ORDER BY total_sales DESC
LIMIT 1;


-- Who are the best customers? (using RFM Analysis: Recency, Frequency, Monetary)
WITH customer_rfm AS
(
    SELECT
        CUSTOMERNAME,
        DATEDIFF(
            (SELECT MAX(STR_TO_DATE(ORDERDATE,'%m/%d/%Y %H:%i'))
             FROM sales_data_sample),
            MAX(STR_TO_DATE(ORDERDATE,'%m/%d/%Y %H:%i'))
        ) AS Recency,
        COUNT(DISTINCT ORDERNUMBER) AS Frequency,
        SUM(SALES) AS Monetary
    FROM sales_data_sample
    GROUP BY CUSTOMERNAME
),

rfm_score AS
(
    SELECT
        *,
        NTILE(4) OVER(ORDER BY Recency ASC) AS r_score,
        NTILE(4) OVER(ORDER BY Frequency DESC) AS f_score,
        NTILE(4) OVER(ORDER BY Monetary DESC) AS m_score
    FROM customer_rfm
),

customer_segment AS
(
    SELECT
        *,
        CONCAT(r_score, f_score, m_score) AS RFM_Score,
        CASE
            WHEN r_score = 4 AND f_score = 4 AND m_score = 4 THEN 'Champion'
            WHEN r_score >= 3 AND f_score >= 3 AND m_score >= 3 THEN 'Loyal Customer'
            WHEN r_score >= 3 AND f_score >= 2 THEN 'Potential Loyalist'
            WHEN r_score = 4 AND f_score = 1 THEN 'New Customer'
            WHEN r_score <= 2 AND f_score >= 3 THEN 'At Risk'
            ELSE 'Needs Attention'
        END AS Customer_Segment
    FROM rfm_score
)

SELECT
    CUSTOMERNAME,
    Recency,
    Frequency,
    Monetary,
    r_score,
    f_score,
    m_score,
    RFM_Score,
    Customer_Segment
FROM customer_segment
ORDER BY Monetary DESC;


-- Which product codes are frequently sold together?

WITH orders_with_two_products AS
(
    SELECT
        ORDERNUMBER
    FROM sales_data_sample
    GROUP BY ORDERNUMBER
    HAVING COUNT(DISTINCT PRODUCTCODE) = 2
)

SELECT
    s1.PRODUCTCODE AS Product_1,
    s2.PRODUCTCODE AS Product_2,
    COUNT(*) AS Times_Bought_Together
FROM sales_data_sample s1
JOIN sales_data_sample s2
    ON s1.ORDERNUMBER = s2.ORDERNUMBER
   AND s1.PRODUCTCODE < s2.PRODUCTCODE
WHERE s1.ORDERNUMBER IN
(
    SELECT ORDERNUMBER
    FROM orders_with_two_products
)
GROUP BY
    s1.PRODUCTCODE,
    s2.PRODUCTCODE
ORDER BY Times_Bought_Together DESC;
