--current store inventory--
select i.buy_vendor_id, v.name, i.cost,
sum(case when i.AVAILABILITY like 'DELETED%' and i.RETURNABLE = 2 then s.on_hand*i.cost else 0 end) del_nonrtn_inv_st,
sum(case when i.AVAILABILITY like 'NOT AVAILABLE%' and i.RETURNABLE =2 then s.on_hand*i.cost else 0 end) nonrtn_notavl_inv_st,
sum(case when i.AVAILABILITY like 'AVAILABLE%' then s.on_hand*i.cost else 0 end) curr_avl_inv_st
from store_inv_fact as s
join lu_item as i on (s.item_key = i.item_key)
join lu_vendor as v on (i.buy_vendor_id = v.vendor_id)
where current_date between inv_start_date and inv_end_date
and grp_dept_id = 3
group by 1,2,3
order by 1,2,3;

--current dc inventory--
select i.buy_vendor_id, v.name, i.cost, 
sum(case when i.AVAILABILITY like 'DELETED%' and i.RETURNABLE = 2 then s.on_hand*i.cost else 0 end) del_nonrtn_inv_dc,
sum(case when i.AVAILABILITY like 'NOT AVAILABLE%' and i.RETURNABLE =2 then s.on_hand*i.cost else 0 end) nonrtn_notavl_inv_dc,
sum(case when i.AVAILABILITY like 'AVAILABLE%' then s.on_hand*i.cost else 0 end) curr_avl_inv_dc
from dc_inv_fact as s
join lu_item as i on (s.item_key = i.item_key)
join lu_vendor as v on (i.buy_vendor_id = v.vendor_id)
where current_date between inv_start_date and inv_end_date
and grp_dept_id = 3
group by 1,2,3
order by 1,2,3;

--cogs & revenue--
select i.buy_vendor_id, v.name, sum(s.net_sales_amt + s.coup_amt) as Revenue, sum(s.net_cost) as COGS
from sales_fact_dtl as s
join lu_item as i on (s.item_key = i.item_key)
join lu_vendor as v on (i.buy_vendor_id = v.vendor_id)
where s.store_id >= '9401'
--and s.bus_date between '2015/03/01' and '2016/02/29'
and s.bus_date between '2014/03/01' and '2015/02/28'
and s.is_ovrng = 'N'
and i.grp_dept_id not in (13,-2,-1)
group by 1,2
order by 1,2;

--receipts--
select h.vendor_id, sum(d.qty*d.std_cost) receipts
from receipt_fact_hdr as h
join receipt_fact_dtl as d on (h.DOC_NO = d.doc_no)
join lu_item as i on (d.ITEM_KEY = i.item_key)
join lu_vendor as v on (i.buy_vendor_id = v.vendor_id)
where v.vend_subtype_id not like '%TRADE%' and v.vend_subtype_id not like '%STORE%'
--and h.RECV_DATE between '2015/03/01' and '2016/02/29'
and h.RECV_DATE between '2014/03/01' and '2015/02/28'
group by 1
order by 1;

--returns--
set isolation to dirty read;

select vendor_id, name
from vendor
where name not like '%HASTINGS%'
and vend_type_id = 1
and inactv_date is null
into temp t_vendor;

select v.vendor_id, v.name, sum(d.qty) qty, sum(d.qty*d.std_cost) inv_cost
from i_return as h
join i_return_dtl as d on (h.doc_no = d.doc_no)
join t_vendor as v on (h.shipto = v.vendor_id)
where h.doc_date between '2015/03/01' and '2016/02/28'
group by 1,2;

--advertising--
drop table t_advertising;
select r.vendor_id, v.name, d.descr, a.adv_id, r.rtp_id, a.descr as ad_descr, 
a.sdate, a.edate, c.adv_clm_id, 
	nvl(case when c.fund_type_id in (2) then clm_amt end,0) as placement_funds,
    nvl(case when c.fund_type_id in(1,3,4) then clm_amt end,0) as non_placement_funds,
    nvl(case when c.adv_clm_id is null and arf.fund_type_id in(2)
             then arf.fund_amt end,0) secured_placement_funds,
	nvl(case when c.fund_type_id is null and arf.fund_type_id in (3,4) 
        then arf.fund_amt end,0) as secured_non_placement_funds,
	nvl(case when c.fund_type_id in(2) then clm_amt end,0) + 
        nvl(case when c.adv_clm_id is null and arf.fund_type_id in(2)
		then arf.fund_amt end,0) as total_rda,
    nvl(case when c.fund_type_id in(1) then clm_amt end,0) + 
        nvl(case when c.adv_clm_id is null and arf.fund_type_id in(1)
        then arf.fund_amt end,0) as total_co_op
from adv_rtp ar
join adv a on (a.adv_id = ar.adv_id)
join rtp r on (ar.rtp_id = r.rtp_id)
left join adv_clm c on (c.adv_id = ar.adv_id) 
    and (c.rtp_id = ar.rtp_id)
left join adv_rtp_fund arf on (ar.adv_id = arf.adv_id) 
    and (ar.rtp_id = arf.rtp_id)
join corp@hast_prd:vendor v on (v.vendor_id = r.vendor_id)
join hyp_prod_dept_sls d on (r.prod_dept_id = d.prod_dept_id)
where a.sdate between '2015/05/01' and '2016/04/30'
and r.rtp_stat_id in (2,3)
order by rtp_id
into temp t_advertising;

select vendor_id, name, sum(placement_funds + non_placement_funds + 
secured_placement_funds + secured_non_placement_funds + total_rda + total_co_op) 
as total_advertising
from t_advertising
group by 1,2
order by 1,2;

--write offs--
drop table if exists t_mkdns;
select item_id, (adj_qty*std_cost) as mkdn_amt
from i_mkdn as i
join i_mkdn_dtl as d on (i.doc_no = d.doc_no)
where doc_date between '2015-05-01' and '2016-04-30'
into temp t_mkdns
with no log;

unload to vendor_writeoffs.unl
select buy_vendor_id, buy_vendor, sum(mkdn_amt) as mkdn_amt
from t_mkdns as i
join product as p on (i.item_id = p.item_id)
group by 1,2
order by 1;
--price protections--
--**run in unix

-------------------------------------------
----query set for secondary video tab------
-------------------------------------------
--current store inventory for video manuf--
select i.buy_vendor_id, i.mfr_id, v.name, sum(i.cost *s.on_hand)
from store_inv_fact as s
join lu_item as i on (s.item_key = i.item_key)
join lu_vendor as v on (i.buy_vendor_id = v.vendor_id)
where current_date between inv_start_date and inv_end_date
and buy_vendor_id in (30002, 2315, 2306, 21207, 36903, 10628)
and grp_dept_id = 3
group by 1,2,3
order by 1,2,3;

--current dc inventory for video manuf--
select i.buy_vendor_id, i.mfr_id, v.name, sum(s.inv_value)
from dc_inv_fact as s
join lu_item as i on (s.item_key = i.item_key)
join lu_vendor as v on (i.buy_vendor_id = v.vendor_id)
where current_date between inv_start_date and inv_end_date
and buy_vendor_id in (30002, 2315, 2306, 21207, 36903, 10628)
and grp_dept_id = 3
group by 1,2,3
order by 1,2,3;

--cogs & revenue for video manuf--
select i.buy_vendor_id, v.name, i.mfr_id, sum(s.net_cost) as COGS, 
sum(s.net_sales_amt + s.coup_amt) as Revenue
from sales_fact_dtl as s
join lu_item as i on (s.item_key = i.item_key)
join lu_vendor as v on (i.buy_vendor_id = v.vendor_id)
where s.store_id >= '9401'
--and s.bus_date between '2015/03/01' and '2016/02/29'
and s.bus_date between '2014/03/01' and '2015/02/28'
and i.buy_vendor_id in (30002, 2315, 2306, 21207, 36903, 10628)
and s.is_ovrng = 'N'
and i.grp_dept_id not in (13,-2,-1)
group by 1,2,3
order by 1,2,3;

--receipts for video manuf--
select h.vendor_id, i.MFR_ID, sum(d.qty*d.std_cost) receipts
from receipt_fact_hdr as h
join receipt_fact_dtl as d on (h.DOC_NO = d.doc_no)
join lu_item as i on (d.ITEM_KEY = i.item_key)
join lu_vendor as v on (i.buy_vendor_id = v.vendor_id)
where v.vend_subtype_id not like '%TRADE%' and v.vend_subtype_id not like '%STORE%'
and h.vendor_id in (30002, 2315, 2306, 21207, 36903, 10628)
--and h.RECV_DATE between '2015/03/01' and '2016/02/29'
and h.RECV_DATE between '2014/03/01' and '2015/02/28'
and i.GRP_DEPT_ID = 3
group by 1,2
order by 1,2;

