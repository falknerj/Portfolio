--get the sales from last week

create temp table t_sales as
select 
a11.ITEM_key,
a15.STATUS,
a15.AVAILABILITY,
a15.PROD_DEPT_ID,
a15.GRP_DEPT_ID,
a15.COST,
vv.NAME as vendor_name,
count(distinct a11.STORE_ID) distinct_stores_with_sales,
sum(a11.NET_SALES_AMT + a11.COUP_AMT)  Revenue,
sum(a11.QTY_SOLD) qty_sold,
sum(a11.NET_SALES_AMT+ a11.COUP_AMT - a11.NET_COST) margin_dlr,
sum(case when a11.MKT_PLC_ID=3 then a11.QTY_SOLD else 0 end) store_units,
sum(case when a11.MKT_PLC_ID!=3 then a11.QTY_SOLD else 0 end) online_units,
count( distinct a11.POS_TRANS_ID || a11.STORE_ID) distinct_transactions
from	SALES_FACT_DTL	a11
	join	REL_IS_GOSHP_ALL	a12
	  on 	(a11.IS_GOSHP_ID = a12.IS_GOSHP_ID)
	join	DBA1.LU_COMP_STORE	a13
	  on 	(a11.STORE_ID = a13.STORE_ID)
	join	REL_STORE_GRP_ALL	a14
	  on 	(a11.STORE_ID = a14.STORE_ID)
	join lu_date dd
		on(a11.BUS_DATE=dd.date)
left join	LU_ITEM	a15
	  on 	(a11.ITEM_KEY = a15.ITEM_KEY)
left join lu_prod_code pc
	on(pc.PROD_CODE = a15.PROD_CODE)
left join dw_stage..PROD_CAT1_stg2 pp1 
on(pp1.PROD_CAT1_KEY= a15.PROD_CAT1_KEY )
left join lu_grp_dept gd
	on(gd.GRP_DEPT_ID = a15.GRP_DEPT_ID)
left join lu_prod_dept pd
on(pd.PROD_DEPT_ID= a15.PROD_DEPT_ID and pd.GRP_DEPT_ID= a15.GRP_DEPT_ID)
 left join dw_stage..PROD_CAT2_stg2 pp2
on(pp2.PROD_CAT2_KEY= a15.PROD_CAT2_KEY )
 left join dw_stage..PROD_CAT3_STG2 pp3
on(pp3.PROD_CAT3_KEY =a15.PROD_CAT3_KEY)
left join lu_vendor vv
on(vv.VENDOR_ID = a15.BUY_VENDOR_ID)
where	(a15.GRP_DEPT_ID not in (-2, -1, 13)
 and a11.IS_OVRNG in ('N')
 and a14.STORE_GRP_ALL_ID in (1000)
 and a13.COMP_FLG in ('G')
 and a12.IS_GOSHP_ALL_ID=40
 and comp_type in(1)

and a15.PROD_DEPT_ID in(117,6,120,106,96,108,95,111)
and a11.STORE_ID not between 9303 and 9346
 and a11.BUS_DATE between (current_date - extract(dow from current_date)+1)-7 and (current_date - extract(dow from current_date)+1)-1
)
group by 1,2,3,4,5,6,7
having sum(a11.qty_sold)>0
;
--get the beginning on_hand

create temp table t_inv as
select v.date, 
v.ITEM_KEY,
	sum(v.ON_HAND) units, 
	sum(v.ON_HAND * i.COST) ext_cost
from v_store_inv_Fact v

left join lu_item i
on (i.ITEM_KEY=v.item_key)
join t_sales t
on(t.item_key= v.ITEM_KEY)
where v.ON_HAND>0
and i.PROD_DEPT_ID not in(107,-2,9,9999,102,101,-1,89)
and v.STORE_ID not between 9303 and 9346
and v.DATE in((current_date - extract(dow from current_date)+1)-7 )

group by 1,2
;

create temp table t_inv_current as
select v.date, 
v.ITEM_KEY,
count(distinct v.STORE_ID) stores_with_inventory,
avg(v.TG_PRC) avg_retail,
	sum(v.ON_HAND) units, 
	sum(v.ON_HAND * i.COST) ext_cost
from v_store_inv_Fact v

left join lu_item i
on (i.ITEM_KEY=v.item_key)
join t_sales t
on(t.item_key= v.ITEM_KEY)
where v.ON_HAND>0
and i.PROD_DEPT_ID not in(107,-2,9,9999,102,101,-1,89)
and v.STORE_ID not between 9303 and 9346
and v.DATE=current_date

group by 1,2
;


--get the current dc on_hand and on_order
create temp table t_inv_dc as
select v.date, 
v.ITEM_KEY,
	sum(v.ON_HAND) dc_oh,
	sum(v.ON_ORDER) dc_oo,
	sum(v.ON_HAND * i.COST) oh_ext_cost,
		sum(v.ON_order * i.COST) oo_ext_cost
from v_dc_inv_Fact v

left join lu_item i
on (i.ITEM_KEY=v.item_key)
join t_sales t
on(t.item_key= v.ITEM_KEY)
where (v.ON_HAND>0 or v.ON_ORDER>0)
and i.PROD_DEPT_ID not in(107,-2,9,9999,102,101,-1,89)
and v.STORE_ID not between 9303 and 9346
and v.DATE =current_date
and v.STORE_ID=7100
group by 1,2
;

create temp table t_receipts as
select r.ITEM_KEY, sum(r.QTY) rcpt_units, sum(r.QTY* r.STD_COST) rcpt_cost
from receipt_fact_dtl r
where r.RECV_DATE between (current_date - extract(dow from current_date)+1)-7 and (current_date - extract(dow from current_date)+1)-1
and r.ITEM_KEY in(select item_key from t_sales)
and store_id>9348
group by 1;


;


create temp table t_selloff as
select t.item_key, t.cost, c.avg_retail, t.vendor_name,a15.prod_code,a15.title,a15.STATUS,
a15.AVAILABILITY,gd.GRP_DEPT_DESCR, pd.PROD_DEPT_DESCR, pp1.PROD_CAT1_DESCR, pp2.PROD_CAT2_DESCR, t.revenue, t.qty_sold, t.margin_dlr, case when t.revenue=0 then 0 else t.margin_dlr/ t.revenue end margin_pct,
t.store_units, 
t.online_units,
t.store_units + t.online_units total_units,
c.stores_with_inventory stores_in_stock,
t.store_units / t.distinct_stores_with_sales as avg_units_per_store,
t.distinct_stores_with_sales,
nvl(i.units,0) beginning_oh,
nvl(c.units,0) current_store_oh,
nvl(di.dc_oh,0) dc_oh,
nvl(di.dc_oo, 0) dc_oo,
nvl(r.rcpt_units,0) receipts,
(nvl(c.units,0)+nvl(di.dc_oh,0)) /(t.store_units+ t.online_units) wos,
row_number() over(partition by prod_dept_descr order by t.revenue desc nulls last) sales_rank,
case when nvl(i.units,0)+nvl(r.rcpt_units,0) =0 then 0 else ((t.store_units + t.online_units)/(nvl(i.units,0)+nvl(r.rcpt_units,0))) end sell_off_pct

from t_sales t
 left join lu_item a15
on( a15.item_key = t.item_key)
left join t_inv i
on(i.item_key=t.item_key)
left join t_inv_current c
on(c.item_key=t.item_key)
left join t_inv_dc di
on(di.item_key=t.item_key)
left join t_receipts r
on(r.item_key=t.item_key)

left join lu_prod_code pc
	on(pc.PROD_CODE = a15.PROD_CODE)
left join dw_stage..PROD_CAT1_stg2 pp1 
on(pp1.PROD_CAT1_KEY= a15.PROD_CAT1_KEY )
left join lu_grp_dept gd
	on(gd.GRP_DEPT_ID = a15.GRP_DEPT_ID)
left join lu_prod_dept pd
on(pd.PROD_DEPT_ID= a15.PROD_DEPT_ID and pd.GRP_DEPT_ID= a15.GRP_DEPT_ID)
 left join dw_stage..PROD_CAT2_stg2 pp2
on(pp2.PROD_CAT2_KEY= a15.PROD_CAT2_KEY )
 left join dw_stage..PROD_CAT3_STG2 pp3
on(pp3.PROD_CAT3_KEY =a15.PROD_CAT3_KEY)	
where case when nvl(i.units,0)+nvl(r.rcpt_units,0) =0 then 0 else ((t.store_units + t.online_units)/(nvl(i.units,0)+nvl(r.rcpt_units,0))) end <.02 or case when nvl(i.units,0)+nvl(r.rcpt_units,0) =0 then 0 else ((t.store_units + t.online_units)/(nvl(i.units,0)+nvl(r.rcpt_units,0))) end >.08
;
create temp table t_top_ten as
select *, row_number() over(partition by prod_dept_descr order by sales_rank asc nulls last) selloff_rank
from t_selloff t
where sell_off_pct>=.08;
select *
from t_top_ten
where selloff_rank<=10;
select *
from t_selloff;