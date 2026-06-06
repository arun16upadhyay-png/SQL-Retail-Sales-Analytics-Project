-- Project Overview --
-- This project analyzes a retail sales dataset using MySQL to uncover business insights related to sales growth, profitability, customer behavior, returns, shipping performance, and customer retention.
-- The objective is to transform raw transactional data into actionable business intelligence through advanced SQL queries, Common Table Expressions (CTEs), Window Functions, Aggregations, and Date Analysis.
 /* Tools Used
•	MySQL
•	SQL (CTEs, Window Functions, Aggregate Functions)
Dataset Information
Tables Used:
 1. sales
 2. calender_file
Data Cleaning
•	Created database and imported datasets.
•	Renamed corrupted column names.
•	Converted date fields into DATE datatype.
•	Checked for missing values.
•	Standardized date formats.
========================================
Business Problems Solved
1. Year-over-Year Sales & Profit Growth
2. Weekend Effect Analysis
3. Best Performing Quarter
4. Discount Trap Analysis
5. Product Return Rate by Region
6. Loss-Making Customers
7. Shipping Delay Analysis
8. Late Delivery Impact
9. Salesperson Performance Dashboard
10. Pareto Analysis (80/20 Rule)
11. Customer Churn Analysis
12. 30-Day Moving Average --
=============================================
*/

-- CREATE DATABASE--
CREATE  DATABASE Sales_data;
USE Sales_data;

-- SHOW TABLE--
SELECT * FROM calender_file LIMIT 10;
SELECT * FROM sales LIMIT 10;

-- DESCRIBE CALENDER TABLE--
DESC  calender_file;

-- UPDATE CALENDER TABLE--
ALTER TABLE calender_file
RENAME COLUMN ï»¿Date TO DATE;

SET SQL_SAFE_UPDATES = 0;

UPDATE calender_file
SET `DATE` = STR_TO_DATE(`DATE`, '%d-%m-%Y');

ALTER TABLE calender_file
MODIFY COLUMN DATE  DATE;

-- UPDATE SALES TABLE --

DESC sales;

ALTER TABLE sales
RENAME COLUMN ï»¿Row_ID TO Row_ID ;

UPDATE sales
SET `OrderDate` = STR_TO_DATE(`OrderDate`, '%d-%m-%Y');

UPDATE sales
SET `OrderDate` = STR_TO_DATE(`OrderDate`, '%d-%m-%Y');

ALTER TABLE sales
MODIFY COLUMN OrderDate  DATE;

ALTER TABLE sales
MODIFY COLUMN ShipDate DATE;

-- SARCH NULL VALUE  IN CALENDER TABLE --
SELECT *
FROM calender_file
WHERE Date IS NULL
   OR Year IS NULL
   OR Quarter IS NULL
   OR `Quarter(Q)` IS NULL
   OR `Quarter_&_Year` IS NULL
   OR Month IS NULL
   OR Month_Name IS NULL
   OR `Month_&_Year` IS NULL
   OR Week_of_Year IS NULL
   OR `Week_of_Year(W)` IS NULL
   OR Day_Name IS NULL;
   
   -- Q.1 Yaer-Over-Year(YOY) Sales & Profit Growth --
 SELECT c.Year,ROUND(SUM(s.Sales),2) AS total_sales,
			   ROUND(SUM(s.Profit),2) AS total_Profit
FROM sales s 
JOIN calender_file c 
ON s.OrderDate = c.DATE
GROUP BY c.Year
ORDER BY c.Year ;            	

-- Q.2 Seasonality(The Weekend Effect) --

SELECT C.Day_Name,
ROUND(SUM(s.Sales),2)AS total_sales,
SUM(CASE WHEN s.Returned = 'Yes' THEN 1 ELSE 0 END) AS total_returns
FROM sales s
JOIN calender_file c  
ON s. OrderDate = c.DATE
GROUP BY c.Day_Name
ORDER BY total_sales DESC ;

-- Q.3 Find The Best Quarter --

SELECT c.Year,
       c.`Quarter(Q)`,
       ROUND(SUM(s.Sales),2) AS total_sales
FROM sales s
JOIN calender_file c
ON s.OrderDate = c.DATE
GROUP BY c.year,
		 c.`Quarter(Q)`
ORDER BY total_sales DESC 
LIMIT 1; 

-- Q.4 Find The Discount Trap --

SELECT Category, `Sub-Category`,
ROUND(SUM(Sales),2) AS total_sales, 
ROUND(AVG(Discount)*100,2) AS avg_discount_pct,
ROund(SUM(Profit),2) AS total_profit
FROM sales 
GROUP BY Category,`Sub-Category`
ORDER BY total_profit ASC; 

-- Q.5 Which region has the highest product return rate? Calculate the return rate (%) for each region and identify the region where customers return the most products."--
SELECT 
    Region,
    COUNT(*) AS total_orders,
    SUM(CASE WHEN Returned = 'Yes' THEN 1 ELSE 0 END) AS returned_orders,
    ROUND(
        (SUM(CASE WHEN Returned = 'Yes' THEN 1 ELSE 0 END) / COUNT(*)) * 100,
        2
    ) AS return_rate_pct
FROM sales
GROUP BY Region
ORDER BY return_rate_pct DESC; 

-- Q.6 find the top 10 Loss-Marking Customers --
SELECT Customer_ID,Customer_Name,
ROUND(SUM(sales),2) AS total_sales,
ROUND(SUM(Profit),2) AS total_loss
FROM sales
GROUP BY Customer_ID,Customer_Name
HAVING total_loss < 0
ORDER BY total_loss ASC
LIMIT 10;

-- Q.7 Shipping Delay Analysis
SELECT 
Ship_Mode,
ROUND(AVG(DATEDIFF(ShipDate,OrderDate)),2) AS avg_shipping_days
FROM sales 
GROUP BY Ship_Mode 
ORDER BY avg_shipping_days; 

-- Q.8 LAte DElivery Impact --
WITH shippingdate AS (
    SELECT
        Order_ID,
        Returned,
        DATEDIFF(ShipDate, OrderDate) AS delivery_days
    FROM sales
)

SELECT
    CASE
        WHEN delivery_days > 3 THEN '(> 3 Days)'
        ELSE 'ON TIME (<= 3 Days)'
    END AS delivery_status,
    COUNT(*) AS total_orders,
    SUM(CASE WHEN Returned = 'Yes' THEN 1 ELSE 0 END) AS returned_orders,
    ROUND(SUM(CASE WHEN Returned = 'Yes' THEN 1 ELSE 0 END) / COUNT(*) * 100,2) AS return_rate_pct
FROM shippingdate
GROUP BY delivery_status;

-- Q.9 Salesperson Perfromance --

SELECT 
	Retail_Sales_People,
    ROUND(SUM(sales),2 )AS Total_sales,
    ROUND(SUM(Profit),2) AS total_profit,
    ROUND((SUM(Profit) / SUM(sales))*100,2) AS profit_margin_pct
FROM sales
GROUP BY Retail_Sales_People
ORDER BY total_sales DESC; 

-- Q.10 The Pareto Principal(80/20 Rule)

WITH customer_sales AS (
    SELECT
        Customer_ID,
        SUM(Sales) AS total_sales
    FROM sales
    GROUP BY Customer_ID
),

ranked_sales AS (
    SELECT
        Customer_ID,
        total_sales,
        SUM(total_sales) OVER (
            ORDER BY total_sales DESC
        ) AS running_total,
        SUM(total_sales) OVER () AS overall_sales
    FROM customer_sales
)

SELECT
    COUNT(Customer_ID) AS top_customer_count,

    (SELECT COUNT(DISTINCT Customer_ID)
     FROM sales) AS total_customer,

    ROUND(
        COUNT(Customer_ID) * 100.0 /
        (SELECT COUNT(DISTINCT Customer_ID)
         FROM sales),
        2
    ) AS pct_of_cust_generating_80_pct_sales

FROM ranked_sales
WHERE running_total <= overall_sales * 0.80; 
 
-- Q.11 Customer Churn

WITH customer_Years AS (
SELECT s.Customer_ID, c.Year
FROM sales s
JOIN calender_file c 
ON c.DATE = s.OrderDate
GROUP BY s.Customer_ID,C.year
)

SELECT DISTINCT Customer_ID FROM customer_years
WHERE Customer_ID IN (SELECT Customer_ID FROM customer_years
WhERE YEAR IN (2015,2016))
AND Customer_id NOT IN (SELECT Customer_ID FROM customer_years WHERE Year = 2017 ); 

-- Q.12 30-Day Moving Average --

WITH daily_sales AS ( 
SELECT c. DATE AS order_date,
SUM(s.sales) AS daily_sales
FROM sales s 
JOIN calender_file c
ON c. DATE = s. OrderDate
GROUP BY order_date)

SELECT
     order_date,
     daily_sales,
     ROUND(AVG(daily_sales) OVER(ORDER BY order_date ROWS BETWEEN 29 PRECEDING AND CURRENT ROW),2) AS 30_day_moving_avg
FROM daily_sales
ORDER BY order_date; 

-- END THE PROJECT --