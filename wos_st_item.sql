create temp table t_stinv as
select s.store_id, s.item_key, i.upc, i.ean, i.prod_code, i.artist_lname, i.title, sum(s.on_hand) st_inv
from store_inv_fact as s
join lu_item as i on (s.ITEM_KEY = i.item_key)
where prod_code in (1, 2, 4, 5, 6, 8, 9, 10, 11, 12, 13, 14, 22, 36, 41, 42, 44, 45, 91, 107, 158, 
161, 162, 163, 340, 341, 342, 343, 371, 373, 378, 379, 405, 458, 483, 482)
and s.ON_HAND > 0
and current_date between s.INV_START_DATE and s.inv_end_date
group by 1,2,3,4,5,6,7;

create temp table t_sales as
select s.store_id, s.item_key, sum(s.qty_sold) wk4_pos
from sales_fact_dtl as s
join lu_item as i on (s.ITEM_KEY = i.item_key)
where prod_code in (1, 2, 4, 5, 6, 8, 9, 10, 11, 12, 13, 14, 22, 36, 41, 42, 44, 45, 91, 107, 158, 
161, 162, 163, 340, 341, 342, 343, 371, 373, 378, 379, 405, 458, 483, 482)
and s.bus_date > (current_date -29)
and s.IS_OVRNG = 'N'
and s.mkt_plc_id = '3'
and i.GRP_DEPT_ID not in (13,-2,-1)
group by 1,2;

create temp table t_full as
select store_id, item_key
from t_stinv
union all
select store_id, item_key
from t_sales
order by store_id, item_key;

create temp table t_avgwk as
select s.store_id, s.item_key, sum(p.wk4_pos / 4) as avg_wk_pos
from t_full as s
join t_sales as p on (s.store_id = p.store_id) and (s.item_key = p.item_key)
group by 1,2;

create temp table t_wos as
select f.store_id, f.item_key, sum(avg_wk_pos / st_inv) as wos
from t_full as f
join t_stinv as s on (f.store_id = s.store_id) and (f.item_key = s.item_key)
join t_avgwk as a on (s.store_id = a.store_id) and (s.item_key = a.item_key)
group by 1,2;

create temp table t_over as
select f.item_key, sum(avg_wk_pos / st_inv) as title_wos
from t_full as f
join t_stinv as s on (f.store_id = s.store_id) and (f.item_key = s.item_key)
join t_avgwk as a on (s.store_id = a.store_id) and (s.item_key = a.item_key)
group by 1;

select s.store_id, s.item_key, s.upc, s.ean, s.prod_code, s.artist_lname, s.title, p.wk4_pos,
a.avg_wk_pos, s.st_inv, w.wos, o.title_wos
from t_full as f
join t_stinv as s on (f.store_id = s.store_id) and (f.item_key = s.item_key)
join t_sales as p on (f.store_id = p.store_id) and (f.item_key = p.item_key)
join t_avgwk as a on (f.store_id = a.store_id) and (f.item_key = a.item_key)
join t_wos as w on (f.store_id = w.store_id) and (f.item_key = w.item_key)
join t_over as o on (f.item_key = o.item_key)
where w.wos < 4;

