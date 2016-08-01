set isolation to dirty read;

select h.shipto, h.shipfrom, c.vendor_id, trim(v.name) vendor_name,
trim(hpd.descr) prod_dept, d.po_no, d.po_line_no, sum(d.qty * d.std_cost) amt, 
case when i.street_date>=doc_date then 'NR' else ' Not NR' end nr_flag, DOC_DATE
from i_recv_jrnl h
join c_recv_jrnl c on(c.corp_id=h.corp_id)
join i_recv_jrnl_dtl d on(d.doc_no= h.doc_no)
join item i on(i.item_id=d.item_id)
join hyp@hyp_prd:hyp_prod_code_sls hp on(hp.prod_code=i.prod_code)
join hyp@hyp_prd:grp_prod_dept gpd on(gpd.prod_dept_id=hp.prod_dept_id)
join hyp@hyp_prd:hyp_grp_dept hgd on(hgd.grp_dept_id=gpd.grp_dept_id)
join hyp@hyp_prd:hyp_prod_dept_sls hpd on(hpd.prod_dept_id=hp.prod_dept_id)
left join vendor v on(v.vendor_id=c.vendor_id)
where doc_date between '2016-06-19' and '2016-06-24'
and ((v.VEND_SUBTYPE_ID not like '%TRADE%' 
    and v.VEND_SUBTYPE_ID != 'STORE') or v.NAME like '%CINRAM%')
and  c.STORE_ID not in(7200,7300,7400,7500,7600,9347)
and d.item_class in(select item_class
                    from glr_inv_spd_key
                    where alias like '%13000%'
                    group by 1)
group by 1,2,3,4,5,6,7,9,10;

