create temp table t_master_item as
select *
from external 'C:\\nonmedia.csv' (item_key bigint)
using (delimiter ','
remotesource 'odbc'
maxerrors 10
logdir 'C:\'
fillrecord);

create temp table t_test as
select i.ITEM_KEY, i.TITLE, i.ARTIST_LNAME, i.ARTIST_FNAME, i.PROD_CODE, pp1.PROD_CAT1_DESCR, 
pp2.PROD_CAT2_DESCR, i.PROD_DEPT_ID,i.GRP_DEPT_ID, vv.NAME, g.GRP_DEPT_DESCR, p.PROD_DEPT_DESCR
from lu_item i
join lu_prod_dept p on(p.PROD_DEPT_ID= i.PROD_DEPT_ID 
						and p.GRP_DEPT_ID= i.GRP_DEPT_ID)
join lu_grp_dept g on(g.GRP_DEPT_ID=p.grp_dept_id)
join lu_prod_cat1 p1 on(p1.PROD_CAT1_KEY= i.PROD_CAT1_KEY 
						and p1.PROD_CODE= i.PROD_CODE)
join lu_prod_cat2 p2 on(p2.PROD_CAT1_KEY= i.PROD_CAT1_KEY 
						and p2.PROD_CODE= i.PROD_CODE 
						and p2.PROD_CAT2_KEY= i.PROD_CAT2_KEY)
join dw_stage..PROD_CAT1_stg2 pp1 on(pp1.PROD_CAT1_KEY= i.PROD_CAT1_KEY 
						and i.PROD_CODE = pp1.PROD_CODE)
join dw_stage..PROD_CAT2_stg2 pp2 on(pp2.PROD_CAT2_KEY= i.PROD_CAT2_KEY)
left join dw..lu_vendor vv on(vv.VENDOR_ID= i.RTN_VENDOR_ID)
where i.GRP_DEPT_ID in(20, 19, 5, 7, 8, 6, 11, 9, 21)
;

select *
from t_master_item as m
inner join t_test as t on (m.item_key = t.item_key);



