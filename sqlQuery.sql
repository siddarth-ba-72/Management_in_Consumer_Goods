-- Provide the list of markets in which customer "Atliq Exclusive" operates its
-- business in the APAC region.
select customer, market
from dim_customer
where customer = "Atliq Exclusive"
and region = "APAC";

-- What is the percentage of unique product increase in 2021 vs. 2020?
with Unique_Products_2020 as (
	select count(distinct p.product_code) as up20
    from dim_product p
    join fact_sales_monthly s
    on p.product_code = s.product_code
    where fiscal_year = 2020
), Unique_Products_2021 as (
	select count(distinct p.product_code) as up21
    from dim_product p
    join fact_sales_monthly s
    on p.product_code = s.product_code
    where fiscal_year = 2021
)
select 
	up20 as "Unique Product 2020", up21 as "Unique Product 2021",
    ((up21 - up20) / up20) * 100 as percentage_chg
from Unique_Products_2020, Unique_Products_2021;

-- Provide a report with all the unique product counts for each segment and
-- sort them in descending order of product counts.
select segment, count(distinct product_code) as prod_cnt
from dim_product
group by segment
order by prod_cnt desc;

-- Which segment had the most increase in unique products in
-- 2021 vs 2020?
select 
	x.segment, x.prod_cnt_2020, y.prod_cnt_2021,
    (y.prod_cnt_2021 - x.prod_cnt_2020) as difference
from (
	select d.segment, count(distinct d.product_code) as prod_cnt_2020
    from dim_product d
    join fact_sales_monthly s
    on d.product_code = s.product_code
    where s.fiscal_year = 2020
    group by d.segment
    order by prod_cnt_2020 desc
) as x
join (
	select d.segment, count(distinct d.product_code) as prod_cnt_2021
    from dim_product d
    join fact_sales_monthly s
    on d.product_code = s.product_code
    where s.fiscal_year = 2021
    group by d.segment
    order by prod_cnt_2021 desc
) as y
on x.segment = y.segment
group by x.segment, x.prod_cnt_2020, y.prod_cnt_2021;

-- Get the products that have the highest and lowest manufacturing costs.
select p.product, p.product_code, m.manufacturing_cost
from dim_product p
join fact_manufacturing_cost m
on p.product_code = m.product_code
where m.manufacturing_cost in (
	(select max(manufacturing_cost) from fact_manufacturing_cost),
    (select min(manufacturing_cost) from fact_manufacturing_cost)
);

-- Generate a report which contains the top 5 customers who received an
-- average high pre_invoice_discount_pct for the fiscal year 2021 and in the
-- Indian market.
select
	c.customer, c.customer_code, 
    avg(p.pre_invoice_discount_pct) as average_discount_percentage
from dim_customer c
join fact_pre_invoice_deductions p
on c.customer_code = p.customer_code
where c.market = "India"
group by c.customer_code, c.customer
order by average_discount_percentage desc
limit 5;

-- In which quarter of 2020, got the maximum total_sold_quantity?
with qtr_table as (
	select *,
    case
		when month(date) in (9, 10, 11) then 'q1'
        when month(date) in (12, 1, 2) then 'q2'
        when month(date) in (3, 4, 5) then 'q3'
        else 'q4'
	end as qtr
    from fact_sales_monthly        
)
select
	sum(sold_quantity) / 1000000 as total_sold_quantity_mln,
    qtr
from qtr_table
where fiscal_year = 2020
group by qtr
order by total_sold_quantity_mln desc;

-- Which channel helped to bring more gross sales in the fiscal year 2021
-- and the percentage of contribution?
with gross_sales_tb as (
	select
		c.channel,
		round(sum(g.gross_price * s.sold_quantity/ 1000000), 2)
		as gross_sales_mln
	from fact_sales_monthly s
	join dim_customer c
	on s.customer_code = c.customer_code
	join fact_gross_price g
	on s.product_code = g.product_code
	where s.fiscal_year = 2021
	group by c.channel
), total_gross_sales_tb as (
	select
		sum(g.gross_price * s.sold_quantity/ 1000000)
		as total_gross_sales_mln
	from fact_sales_monthly s
	join fact_gross_price g
	on s.product_code = g.product_code
	where s.fiscal_year = 2021
)
select
	channel,
    gross_sales_mln,
    round((gross_sales_mln/total_gross_sales_mln * 100), 2)
    as gross_sales_pct
from gross_sales_tb, total_gross_sales_tb
group by channel, gross_sales_pct
order by gross_sales_pct desc;

-- Get the Top 3 products in each division that have a high
-- total_sold_quantity in the fiscal_year 2021?
select * from (
	select *,
		dense_rank() over(partition by division order by total_sold_qty desc)
        as rank_order
	from (
		select
			p.product_code, p.product, p.division,
            sum(s.sold_quantity) as total_sold_qty
		from dim_product p
        join fact_sales_monthly s
        on p.product_code = s.product_code
        where s.fiscal_year = 2021
        group by p.product_code, p.product, p.division
    ) as y
) as x
where rank_order < 4;


