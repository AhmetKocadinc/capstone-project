select * from categories
select * from customers
select * from employees
select * from employeeterritories
select * from order_details
select * from orders
select * from products
select * from region
select * from shippers
select * from suppliers
select * from territories
select * from usstates

-- SİPARİŞ ANALİZİ

-- Shippers analizi

SELECT 
    EXTRACT(year FROM o.shipped_date) AS shipped_years,
    TO_CHAR(o.shipped_date, 'Month') AS shipped_months,
	s.shipper_id,
    s.company_name AS kargo_name,
    COUNT(o.order_id) AS toplam_urun_adedi
FROM 
    orders o
JOIN
    shippers s ON o.ship_via = s.shipper_id
GROUP BY 
    1,2,3,4
ORDER BY 
    toplam_urun_adedi DESC;
	
	
-- Şirketin yıllara göre ciroları nasıldır ?

select 
	extract(year from order_date) as year,
	round(sum(od.quantity * od.unit_price)) as total_price
from orders o
join order_details od on o.order_id = od.order_id
group by 1
order by 2 desc

-- Şirketin aylara göre cirolarını getirin

select
	extract(month from order_date) as months,
	extract(year from order_date) as years,
	round(sum(od.quantity * od.unit_price)) as total_price
from orders o
join order_details od on o.order_id = od.order_id
group by 1,2
order by 3 desc


-- En çok satan ürünlerimiz hangileridir?

select 
	 sum(quantity),
	 product_name
from 
	products as p
join order_details as od on	p.product_id = od.product_id
group by 2
order by 1 desc


-- En çok kazanç sağlayan ürünlerimiz hangileridir?

with total_price as(
select 
	extract(year from o.order_date) as years,
	TRIM(TO_CHAR(o.order_date, 'Month')) AS months,	
	round(sum(od.quantity * od.unit_price)) as total_price,
	product_name
from 
	products as p
join order_details as od on	p.product_id = od.product_id
join orders as o on od.order_id=o.order_id
group by 1,2,4
order by 3 desc
)

select 
	round(sum(total_price)),
	product_name
from 
	total_price
group by 2
order by 1 desc


-- En çok satış yapılan kategori ve kategoriye ait ürünler hangileridir ?

select 
	category_name,
	product_name,
	count(order_id)
from
	products p
join order_details od on p.product_id = od.product_id
join categories cat on p.category_id = cat.category_id
group by 1,2
order by 3 desc

select count(category_name) from categories

-- Farklı kategorilerdeki ürünlerin ortalama fiyatı ve toplam satış tutarı nedir ?

select 
	ct.category_name,
	p.product_name,
	round(avg(od.unit_price)) as avg_price,
	round(sum(od.quantity*od.unit_price)) total_price
from
	products p
join order_details od on p.product_id = od.product_id
join categories ct on p.category_id = ct.category_id
group by 1,2
order by 3 desc

-- Yıllara göre en çok satan ürünler

select 
	extract(year from order_date) as year,
	product_name,
	round(sum(od.quantity * od.unit_price)) as total_price
from orders o
join order_details od on o.order_id = od.order_id
join products p on od.product_id = p.product_id
group by 1,2
order by 3 desc


-- En çok satış yapılan ve getiri sağlayan ülke hangidir ?

select 
	ship_country,
	count(od.order_id),
	round(sum(od.unit_price*od.quantity))
from orders o
join order_details od on o.order_id=od.order_id
group by 1
order by 2 desc

-- En çok getiri sağlanan ülke hangisidir ?

select 
	ship_country,
	count(order_id)
from 
	orders as o
group by 1
order by 2 desc

select 
	ship_country, 
	round(sum(od.unit_price*od.quantity))
from orders o
join order_details od on o.order_id=od.order_id
group by 1
order by 2 desc


-- En çok hangi kargo firması kullanılmaktadır ?

select
	count(order_id) total_orders,
	company_name
from
	orders as o
join shippers as sp on o.ship_via=sp.shipper_id
group by 2
order by 1 desc

-- MÜŞTERİ ANALİZİ

-- Hangi bölgede ne kadar müşterimiz var ?

select 
	country,
	city,
	count(customer_id)
from customers
group by 1,2
order by 3 desc


-- RFM Analizi

-- Recency

with last_order as (
	select
		customer_id as customer,
		max(order_date) as last_orders
	from
		orders
	group by 1
	order by 2 desc
)


select 
	customer,
	(select max(order_date) from orders)- last_orders as recency
from
	last_order
order by 2


-- Frequency

select 
	customer_id,
	count(order_id)
from orders
group by 1
order by 2 desc

-- Monetary

select 
	customer_id,
	round(sum(unit_price*quantity)) as monetary
from 
	order_details od
join orders o on od.order_id=o.order_id
group by 1
order by 2 desc

-- RFM skorunun hesaplanması ve müşteri segmentasyonunun yapılması

WITH last_order AS (
    SELECT
        customer_id AS customer,
        MAX(order_date) AS last_orders
    FROM
        orders
    GROUP BY
        customer_id
),

net_recency AS (
    SELECT 
        customer,
        (SELECT MAX(order_date) FROM orders) - last_orders AS recency
    FROM
        last_order
),

recency AS (
    SELECT
        customer,
        recency,
        ntile(5) OVER (ORDER BY recency) AS recency_score
    FROM
        net_recency
),

net_frequency AS (
    SELECT 
        customer_id,
        COUNT(order_id) AS total_order
    FROM orders
    GROUP BY
        customer_id
),

frequency AS (
    SELECT 
        customer_id,
        total_order,
        ntile(5) OVER (ORDER BY total_order DESC) AS frequency_score
    FROM net_frequency
),

net_monetary AS(
    SELECT 
        customer_id,
        ROUND(SUM(unit_price * quantity)) AS monetary
    FROM 
        order_details
    JOIN orders ON order_details.order_id = orders.order_id
    GROUP BY
        customer_id
),

monetary AS (
    SELECT 
        customer_id,
        monetary,
        ntile(5) OVER (ORDER BY monetary DESC) AS monetary_score
    FROM 
        net_monetary
),

rfm_scores AS (
    SELECT 
        r.customer AS customer_id,
        recency,
        f.total_order AS frequency,
        m.monetary,
        recency_score,
        frequency_score,
        monetary_score,
        CONCAT(recency_score::text, frequency_score::text) AS rfm_score
    FROM recency r
    JOIN frequency f ON r.customer = f.customer_id
    JOIN monetary m ON r.customer = m.customer_id
)

SELECT
    customer_id,
	recency,
	frequency,
	monetary,
	recency_score,
    frequency_score,
    monetary_score,
    rfm_score,
    CASE
        WHEN rfm_score ~ '^[1-2][1-2]$' THEN 'Hibernating'
        WHEN rfm_score ~ '^[1-2][3-4]$' THEN 'At_risk'
        WHEN rfm_score ~ '^[1-2]5$' THEN 'Cant_loose'
        WHEN rfm_score ~ '^3[1-2]$' THEN 'About_the_sleep'
        WHEN rfm_score = '33' THEN 'Need_attention'
        WHEN rfm_score ~ '^[3-4][4-5]$' THEN 'Loyal_customers'
        WHEN rfm_score = '41' THEN 'Promising'
        WHEN rfm_score = '51' THEN 'New_customers'
        WHEN rfm_score ~ '^[4-5][2-3]$' THEN 'Potential_loyalists'
        WHEN rfm_score ~ '^5[4-5]$' THEN 'Champions'
        ELSE 'Other' -- Bu satır, hiçbir koşula uymayan skorlar için kullanılır.
    END AS customer_segment
FROM
    rfm_scores;


-- ÇALIŞAN ANALİZİ

-- En yüksek satış yapan çalışanımız hangisidir, kaç adet ürün satmıştır ve bu satıştan elde ettiği tutar nedir ? Yıllara göre bir tablo çıkaralım ve görselleştirelim.

with employee_prices as (
select 
	e.first_name || ' ' || e.last_name full_name,
	e.title,
	p.product_name,
	extract(year from order_date) years,
	count(od.quantity) total_quantity,
	round(avg(od.unit_price)) avg_prices,
	round(sum(od.quantity*od.unit_price)) total_price
from 
	orders o
join employees e on o.employee_id=e.employee_id
join order_details od on o.order_id=od.order_id
join products p on od.product_id=p.product_id
group by 1,2,3,4
order by 7 desc
)

select 
	full_name,
	years,
	count(total_quantity) total_quantity,
	sum(total_price) total_price
from employee_prices
group by 1,2
order by 4 desc

-- Çalışanlarımız bize hangi bölgeden destek veriyorlar ? 

select 
	country,
	city,
	count(employee_id)
from employees
group by 1,2
order by 3 desc

-- Çalışanlarımızın yaş ortalaması nedir ? 

with employee_age as (
select 
	first_name || ' ' || last_name employee_name,
	1998-extract(year from birth_date) age
from employees
)

select 
	employee_name,
	age,
	case
		when age >=20 and age <=30 then '20-30'
		when age >=30 and age <=40 then '30-40'
		when age >=40 and age <=50 then '40-50'
		when age >=50 and age <=60 then '50-60'
		else '60+' end avg_age
from employee_age




