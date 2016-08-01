run in aqua data
select pickup_trans, store_id
from pos_trans@sum_prd:pos_trans_presell p
where pickup_trans is not null
group by 1,2;
--save to c drive in csv file for the path below.

--run in aginity
Create temp table t_pickup_ as
select *
from external 'C:\\CSV files for Netezza\pickup_trans.csv'
(pos_trans_id  bigint, store_id bigint)
using (
delimiter ','
remotesource 'odbc'
skiprows 1
maxerrors 10
logdir 'C:\'
fillrecord);
       
create temp table t_reservation as
select a11.POS_TRANS_ID, a11.STORE_ID, 
case when  street_date=current_date-1 and title like '%DEAD%POOL%' and a15.PROD_DEPT_ID not in(98,3,100) 
	then 'Deadpool' when title like '%UNCHARTED%' and street_date=current_date-1 
	and a15.PROD_DEPT_ID not in(98,3,100)  then 'Uncharted' else 'ZOther' end title_type,
case when p.pos_trans_id is null then 'Non Reservation' else 'Reservation' end reservation_flag
from SALES_FACT_DTL as a11
	join REL_IS_GOSHP_ALL as a12 on (a11.IS_GOSHP_ID = a12.IS_GOSHP_ID)
	join DBA1.LU_COMP_STORE as a13 on (a11.STORE_ID = a13.STORE_ID)
	join REL_STORE_GRP_ALL as a14 on (a11.STORE_ID = a14.STORE_ID)
	join lu_date as dd on (a11.BUS_DATE=dd.date)
	left join t_pickup_ as p on (p.pos_trans_id = a11.POS_TRANS_ID and p.store_id = a11.STORE_ID)
	left join LU_ITEM as a15 on (a11.ITEM_KEY = a15.ITEM_KEY)
	left join lu_prod_code as pc on (pc.PROD_CODE = a15.PROD_CODE)
	left join dw_stage..PROD_CAT1_stg2 as pp1 on (pp1.PROD_CAT1_KEY= a15.PROD_CAT1_KEY )
	left join lu_grp_dept as gd on (gd.GRP_DEPT_ID = a15.GRP_DEPT_ID)
	left join lu_prod_dept as pd on (pd.PROD_DEPT_ID= a15.PROD_DEPT_ID and pd.GRP_DEPT_ID= a15.GRP_DEPT_ID)
	left join dw_stage..PROD_CAT2_stg2 as pp2 on (pp2.PROD_CAT2_KEY= a15.PROD_CAT2_KEY )
	left join dw_stage..PROD_CAT3_STG2 as pp3 on (pp3.PROD_CAT3_KEY =a15.PROD_CAT3_KEY) 
where (a15.GRP_DEPT_ID not in (-2, -1, 13)
	and a11.IS_OVRNG in ('N')
	and a14.STORE_GRP_ALL_ID in (1000)
	and a13.COMP_FLG in ('G')
	and a12.IS_GOSHP_ALL_ID=30
	and comp_type in(1)
	and a11.STORE_ID!=9000
	and a11.STORE_ID not between 9303 and 9346
	and a11.BUS_DATE =current_date-1)
group by 1,2,3,4;

create temp table t_reservation_ as
select pos_trans_id, store_id, min(title_type) title_type, min(reservation_flag) reservation_flag
from t_reservation
group by 1,2;

select a11.POS_TRANS_ID, a11.STORE_ID, t.reservation_flag, t.title_type,
sum(a11.NET_SALES_AMT + a11.COUP_AMT) revenue, 
sum(a11.NET_SALES_AMT + a11.COUP_AMT - a11.NET_COST) margin_dlr
from SALES_FACT_DTL as a11
	join REL_IS_GOSHP_ALL as a12 on (a11.IS_GOSHP_ID = a12.IS_GOSHP_ID)
    join DBA1.LU_COMP_STORE as a13 on (a11.STORE_ID = a13.STORE_ID)
    join REL_STORE_GRP_ALL as a14 on (a11.STORE_ID = a14.STORE_ID)
    join lu_date as dd on (a11.BUS_DATE=dd.date)
	left join t_reservation_ as t on (t.pos_trans_id= a11.POS_TRANS_ID and t.store_id= a11.STORE_ID)
	left join LU_ITEM as a15 on (a11.ITEM_KEY = a15.ITEM_KEY)
	left join lu_prod_code as pc on (pc.PROD_CODE = a15.PROD_CODE)
	left join dw_stage..PROD_CAT1_stg2 as pp1 on (pp1.PROD_CAT1_KEY= a15.PROD_CAT1_KEY )
	left join lu_grp_dept as gd on (gd.GRP_DEPT_ID = a15.GRP_DEPT_ID)
	left join lu_prod_dept as pd on (pd.PROD_DEPT_ID= a15.PROD_DEPT_ID and pd.GRP_DEPT_ID= a15.GRP_DEPT_ID)
	left join dw_stage..PROD_CAT2_stg2 as pp2 on (pp2.PROD_CAT2_KEY= a15.PROD_CAT2_KEY )
	left join dw_stage..PROD_CAT3_STG2 as pp3 on (pp3.PROD_CAT3_KEY =a15.PROD_CAT3_KEY) 
where (a15.GRP_DEPT_ID not in (-2, -1, 13)
	and a11.IS_OVRNG in ('N')
	and a14.STORE_GRP_ALL_ID in (1000)
	and a13.COMP_FLG in ('G')
	and a12.IS_GOSHP_ALL_ID=30
	and a11.STORE_ID!=9000
	and comp_type in(1)
	and a11.STORE_ID not between 9303 and 9346
	and a11.BUS_DATE=current_date-1)
group by 1,2,3,4;

