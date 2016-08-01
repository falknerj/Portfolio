drop table t_base;
drop table t_id;
drop table t_stinv;
drop table t_dcinv;

select m.item_id, p.upc, p.artist_lname, p.title, p.status, p.availability, 
m.sdate, m.edate, m.min_prc, m.actv 
from web_min_prc_item as m
join product as p on (m.item_id = p.item_id)
where p.buy_vendor_id = 35777
into temp t_base;

select b.item_id, 
    case when barcode_type_id=1 then barcode else null end upc,
    case when barcode_type_id=2 then barcode else null end ISBN,
    case when barcode_type_id=3 then barcode else null end EAN,
    case when barcode_type_id=4 then barcode else null end ITEM_number,
    case when barcode_type_id=5 then barcode else null end UPC_S,
    case when barcode_type_id=6 then barcode else null end ISBNS,
    case when barcode_type_id=7 then barcode else null end GNRIC,
    case when barcode_type_id=8 then barcode else null end MAG,
    case when barcode_type_id=9 then barcode else null end GTIN,
    case when barcode_type_id=10 then barcode else null end UPCS2,
    case when barcode_type_id=11 then barcode else null end UPC_5,
    case when barcode_type_id=12 then barcode else null end UPCS3
from item_barcode b
join t_base as a on (b.item_id = a.item_id)
order by item_number desc
into temp t_id;

select a.item_id, sum(s.on_hand) as st_oh
from store_item as s
join t_base as a on (s.item_id = a.item_id)
where s.store_id not in (7000, 7100, 7200, 7700, 9000)
group by 1
into temp t_stinv;

select a.item_id, sum(s.on_hand) as dc_oh
from store_item as s
join t_base as a on (s.item_id = a.item_id)
where s.store_id in (7000, 7100, 7200, 7700, 9000)
group by 1
into temp t_dcinv;

select a.item_id, a.upc, i.item_number, a.artist_lname, a.title, a.status, 
a.availability, a.sdate, a.edate, a.min_prc, a.actv, s.st_oh, d.dc_oh
from t_base as a
join t_id as i on (a.item_id = i.item_id)
left join t_stinv as s on (a.item_id = s.item_id)
left join t_dcinv as d on (a.item_id = d.item_id);
