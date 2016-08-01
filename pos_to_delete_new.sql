set lock mode to wait 60;

create temp table t_update_pos
(po_id				integer,
 line_num			integer,
 po_stat_id			character(5),
 expd_recv_qty		integer)
with no log;

load from pos_to_delete.csv
delimiter ","
insert into t_update_pos;

select t.po_id, t.line_num, t.po_stat_id, t.expd_recv_qty
from t_update_pos t, po_dtl d
where t.po_id = d.po_id
and t.line_num = d.line_num
and d.expd_recv_qty >= 0
and d.po_stat_id != "CAN"
into temp t_updates
with no log;

begin work;

merge into po_dtl as a
using t_updates as b on (a.po_id = b.po_id) and (a.line_num = b.line_num)
when matched then
update set a.po_stat_id = b.po_stat_id, a.expd_recv_qty = b.expd_recv_qty;

commit work;