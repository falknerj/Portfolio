--DESCRIPTION:  Outstanding POs by Department

--TO USE:  Run Query

--UNLOAD:  po_outstanding_NRA.unl

set isolation to dirty read;

create temp table t_pc_num_days
(prod_code   smallint,
 num_days    smallint)
with no log;

load from po_pc_num_days.csv
delimiter ","
insert into t_pc_num_days;

create temp table t_dept_num_days
(prod_dept_id   smallint,
 num_days       smallint)
with no log;

load from po_dept_num_days.csv
delimiter ","
insert into t_dept_num_days;

--drop table t_pos;
select hpc.prod_dept_id, i.prod_code,
       p.shipto_id, p.vendor_id, p.po_id, p.po_dt, p.po_type_id,
       p.po_stat_id po_status,
       p.po_xmit_type_id, d.item_id,
       d.line_num, d.po_stat_id line_status, d.ship_dt, d.po_qty,
      (case when i.item_status_id = "PP" and d.recv_qty != 0 then d.po_qty
             when i.item_status_id = "PP" and d.recv_qty = 0 then d.recv_qty
        else d.recv_qty
        end) recv_qty,
      d.expd_recv_qty, d.po_cost, d.expd_ship_dt
from po p, po_dtl d, item i, hyp_prod_code_sls hpc, store s
where p.po_id = d.po_id
and d.item_id = i.item_id
and i.prod_code = hpc.prod_code
and p.shipto_id = s.store_id
and hpc.prod_dept_id not in (-2,-1,9,89,191,102,9999)
and p.po_stat_id not in ("CLS", "CAN")
and d.po_stat_id not in ("CLS", "CAN", "DEL", "NOF")
and p.vendor_id not in (10577, 2500)
and d.expd_recv_qty > 0
and (s.close_date is null
 or s.close_date > today)
into temp t_pos
with no log;

select t.prod_dept_id, t.prod_code,
       t.shipto_id, t.vendor_id, t.po_id, t.po_dt, t.po_type_id,
       t.po_status, t.po_xmit_type_id, t.item_id,
       t.line_num, t.line_status, t.ship_dt,
       t.po_qty, t.recv_qty, t.expd_recv_qty, t.po_cost, t.expd_ship_dt,
       today - t.po_dt num_days
from t_pos t, item i
where t.item_id = i.item_id
and i.street_date < today
and t.expd_ship_dt < today
and t.po_dt < today -14
into temp t_num_days
with no log;

select t.po_id, t.line_num
from t_num_days t, t_pc_num_days p
where t.prod_code = p.prod_code
and t.num_days >= p.num_days
into temp t_num_days_exceeded
with no log;

select t.po_id, t.line_num
from t_num_days_exceeded t
into temp t_delete_pos
with no log;

delete from t_pos
where po_id||line_num in (select po_id||line_num from t_num_days_exceeded);

select t.po_id, t.line_num
from t_pos t
where t.prod_dept_id = 105
and t.po_dt <= "01/01/2012"
into temp t_used_games_harware
with no log;

insert into t_delete_pos
select t.po_id, t.line_num
from t_used_games_harware t;

delete from t_pos
where po_id||line_num in (select po_id||line_num from t_used_games_harware);

select t.po_id, t.line_num
from t_num_days t, t_dept_num_days p
where t.prod_dept_id = p.prod_dept_id
and t.num_days >= p.num_days
into temp t_dept_num_days_exceeded
with no log;

insert into t_delete_pos
select t.po_id, t.line_num
from t_dept_num_days_exceeded t;

delete from t_pos
where po_id||line_num in
      (select po_id||line_num from t_dept_num_days_exceeded);

unload to delete_pos.unl
select t.po_id, t.line_num
from t_delete_pos t
order by 1,2;

select t.prod_dept_id, t.prod_code,
       t.shipto_id, t.vendor_id, t.po_id, t.po_dt,
       (case when t.po_dt + 21 <= t.expd_ship_dt then t.expd_ship_dt
             when t.po_dt + 21 <= i.street_date then i.street_date
             else t.po_dt + 21
        end) recv_date,
       t.po_type_id, t.po_status, t.po_xmit_type_id, t.item_id,
       t.line_num, t.line_status, t.ship_dt,
       t.po_qty, t.recv_qty, t.expd_recv_qty, t.po_cost, t.expd_ship_dt
from t_pos t, item i
where t.item_id = i.item_id
and i.street_date < today
and t.expd_recv_qty > 0
and t.expd_ship_dt < today
and t.po_dt < today -14
into temp t_recv_date
with no log;

unload to po_outstanding_by_dept.unl
select hpd.descr, p.prod_code, p.prod_cat1, p.prod_cat2,
       t.item_id, p.upc, p.ean, p.isbn,
       p.artist_lname, p.artist_fname, p.title, p.status,
       p.availability, p.returnable, p.street_date, p.cost, t.vendor_id,
       v.name, t.shipto_id,
       t.po_id, t.line_num, t.po_dt, today - t.po_dt po_age,
       t.expd_ship_dt, t.recv_date,
       t.po_type_id, t.po_status,
       t.line_status, t.po_cost,
       t.po_qty, t.po_cost * t.po_qty po_ext_amt, t.recv_qty,
       t.expd_recv_qty,
       (case when p.status = "PP" and t.recv_qty != 0
                  then t.po_qty * t.po_cost
             when p.status = "PP" and t.recv_qty = 0 then 0
            else t.expd_recv_qty * t.po_cost
        end) outstanding_amt
from t_recv_date t, product p, hyp_prod_code_sls hpc, hyp_prod_dept_sls hpd,
     vendor v
where t.item_id = p.item_id
and p.prod_code = hpc.prod_code
and hpc.prod_dept_id = hpd.prod_dept_id
and t.vendor_id = v.vendor_id
and t.recv_date <=  today
and t.po_type_id != "ECO"
order by 1,2,3,4,5,19,20,21;
