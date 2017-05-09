--################################################################
--##								##
--## GENERATE RECEPTORS FROM MASTERMAP POLYGON CENTROIDS	##
--## Most likely facade chosen by road frc			##
--## receptors shifted 1m with respect to nearest road		##
--## or perpendicular to nearest facade				##
--##								##
--## David Morley: d.morley@imperial.ac.uk			##
--## Version 0.0, 5th February 2014				##
--##								##	
--################################################################

------------------------------------------------------------------
--## Road network 	: 	ITN_london
--## Building Polygons	:	mm_bh_ne
------------------------------------------------------------------

--dissolve buildings and get exterior walls
drop table if exists lnes;
drop index if exists idx1;
create table lnes as
select (st_makeline(sp,ep)) as geom
from
   (select
      st_pointn(geom, generate_series(1, st_npoints(geom)-1)) as sp,
      st_pointn(geom, generate_series(2, st_npoints(geom)  )) as ep
    from
      (select (st_dump(st_boundary(geom))).geom
       from 
	(select (st_dump(st_union(p.geom))).geom as geom
	from mm_bh_ne as p) as dissolved
       ) as linestrings
    ) as segments;  
alter table lnes add id serial;
select UpdateGeometrySRID('public', 'lnes', 'geom', 27700);
create index idx1 on lnes using gist (geom);

--create 10m points on lines
drop table if exists pnts;
drop index if exists idx2;
create table pnts as 
with wall as (
	select l.id, get_steprat(st_length(l.geom), 10) as step, l.geom
	from lnes as l
)
select s.id, st_line_interpolate_point(s.geom, cast(s.pstep as double precision) / 100000) as geom
from (
	select w.id, generate_series(w.step / 2, 100000, w.step) as pstep, w.geom
	from wall as w
) as s;
select UpdateGeometrySRID('public', 'pnts', 'geom', 27700);
create index idx2 on pnts using gist (geom);

--match points to buildings and roads
drop table if exists nodes;
create table nodes as
with nn as (
	select p.geom, 
	nnid(p.geom, 1, 2, 50, 'mm_bh_ne', 'mm_id', 'geom') as mm_id,
	nnid(p.geom, 1, 2, 1000, 'ITN_london', 'gid', 'geom') as nn_road
	from pnts as p
)
select n.geom, n.mm_id, get_frc(r.legend) as frc, st_distance(r.geom, n.geom) as dist, r.gid as road
from nn as n left join ITN_london as r
on n.nn_road = r.gid;
alter table nodes add id serial;

--count duplicates
drop table if exists duplicates;
create table duplicates as
with x as (
	select min(n.dist), n.mm_id, n.frc
	from nodes as n
	group by n.mm_id, n.frc
)
select count(x.mm_id), x.mm_id
from x group by x.mm_id;

--get facade node
drop table if exists facade1;
drop index if exists idx3;
create table facade1 as
select n.geom, n.road, f.mm_id from
(select get_facade(d.count, d.mm_id) as facade_node, d.mm_id
from duplicates as d) as f
left join nodes as n
on n.id = f.facade_node;
select UpdateGeometrySRID('public', 'facade1', 'geom', 27700);
create index idx3 on facade1 using gist (geom);

--shift facade point orthogonally by 1m, 
--wrt building facade
drop table faces;
create table faces as
with nl as (
	select nnid(p.geom, 1, 2, 50, 'lnes', 'id', 'geom') as lid, p.mm_id, p.geom as pnt
	from facade1 as p
)
select l.geom, nl.mm_id, nl.pnt
from nl left join lnes as l
on nl.lid = l.id;
drop table if exists facade2;
create table facade2 as
select mm_id,
st_line_interpolate_point(st_offsetcurve(f.geom, 1), st_line_locate_point(f.geom, f.pnt)) as geom
from faces as f;

--shift facade point orthogonally by 1m, 
--wrt nearest road
-- select degrees(st_azimuth(f.geom, st_closestpoint(r.geom, f.geom))), f.geom
-- from facade1 as f, ITN_london as r
-- where f.road = r.gid;
-- 
-- drop table if exists facade3;
-- create table facade3 as
-- with bearing as (
-- 	select st_azimuth(f.geom, st_closestpoint(r.geom, f.geom)) as angle, 
-- 	st_x(f.geom) as x, st_y(f.geom) as y, f.mm_id
-- 	from facade1 as f, itn_x as r
-- 	where f.road = r.gid
-- )
-- select b.mm_id,
-- st_geomfromtext('POINT('|| b.x + (sin(angle) * 1) || ' ' || b.y + (cos(angle) * 1) ||')') as geom
-- from bearing as b;



--################
--## Functions  ##
--################

--get the point assumed to be on the facade
create or replace function get_facade(c bigint, i integer)
returns integer as $$
declare 
	node integer;
	dt double precision;
begin
	if c > 1 then --duplicates
	
		--find if more than 1 point over 30m
		select count(*)
		from nodes as n
		where n.mm_id = i
		and n.dist > 30
		into dt;

		if dt = 0 then
			--if all less than 30m take the min dist regardless of priority
			select n.id
			from nodes as n
			where n.mm_id = i
			order by n.dist
			limit 1 into node;
		else
			--if all over 30m take the lowest priority road that is closest
			select n.id
			from nodes as n
			where n.mm_id = i
			order by n.frc, n.dist
			limit 1 into node;
		end if;
	else
		--where frc is minimum distance
		with house as (
			select n.dist, n.id
			from nodes as n
			where n.mm_id = i
		)
		select h.id
		from house as h
		order by h.dist
		limit 1 into node;
	end if;
	return node;
end
$$ language 'plpgsql' stable;


drop table road_lut;
create table road_lut 
(
	legend character varying(45),
	frc integer
);
insert into road_lut values ('Motorway dual carriageway', 10);
insert into road_lut values ('Motorway single carriageway', 10);
insert into road_lut values ('Motorway link/rdbt/slip road', 10);
insert into road_lut values ('Primy A rd dual carriageway', 1);
insert into road_lut values ('Primy A rd single carriageway', 1);
insert into road_lut values ('Primary A rd link/rdbt/slip road', 1);
insert into road_lut values ('A road dual carriageway', 2);
insert into road_lut values ('A road single carriageway', 2);
insert into road_lut values ('A road link/rdbt/slip road', 2);
insert into road_lut values ('Primy A rd link/rdbt/slip road', 1);
insert into road_lut values ('Primary B rd link/rdbt/slip road', 3);
insert into road_lut values ('B road dual carriageway', 4);
insert into road_lut values ('B road single carriageway', 4);
insert into road_lut values ('B road link/rdbt/slip road', 4);
insert into road_lut values ('Minor road dual carriageway', 5);
insert into road_lut values ('Minor road single carriageway', 5);
insert into road_lut values ('Minor road link/rdbt/slip road', 5);
insert into road_lut values ('Local street dual carriageway', 6);
insert into road_lut values ('Local street single carriageway', 6);
insert into road_lut values ('Local street sngle carriageway', 6);
insert into road_lut values ('Local street link/rdbt/slip rd', 6);
insert into road_lut values ('Pvt rd pub acc dual c’way', 7);
insert into road_lut values ('Pvt rd pub acc single c’way', 7);
insert into road_lut values ('Pvt rd pub acc link/rdbt/slip', 7);
insert into road_lut values ('Pvt rd pvt access dual c’way', 7);
insert into road_lut values ('Pvt rd pvt access single c’way', 7);
insert into road_lut values ('Pvt rd pvt acc link/rdbt/slip', 7);
insert into road_lut values ('Alley', 7);
insert into road_lut values ('Pedestrianised street', 8);


--functional road class
drop function get_frc(text);
create or replace function get_frc(key text)
returns integer as $$
declare 
	frcx integer;
begin
	select l.frc from road_lut as l
	where key = l.legend into frcx;
	return frcx;
end
$$ language 'plpgsql' stable;

--get step ratio
create or replace function get_steprat(lgth double precision, x integer)
returns integer as $$
declare 
	step integer;
begin
	if lgth < x then
		--take only midpoint of road sections < x m long
		step := 100000;
	else
		--x metre intervals
		step := cast(trunc(100000 / (lgth / x)) as integer);
	end if;
	return step;
end
$$ language 'plpgsql' stable;

--nearest neighbour id
create or replace function  nnid(nearto geometry, initialdistance real, distancemultiplier real, 
maxpower integer, nearthings text, nearthingsidfield text, nearthingsgeometryfield  text)
returns integer as $$
declare 
  sql text;
  result integer;
begin
  sql := ' select ' || quote_ident(nearthingsidfield) 
      || ' from '   || quote_ident(nearthings)
      || ' where st_dwithin($1, ' 
      ||   quote_ident(nearthingsgeometryfield) || ', $2 * ($3 ^ $4))'
      || ' order by st_distance($1, ' || quote_ident(nearthingsgeometryfield) || ')'
      || ' limit 1';
  for i in 0..maxpower loop
     execute sql into result using nearto             -- $1
                                , initialdistance     -- $2
                                , distancemultiplier  -- $3
                                , i;                  -- $4
     if result is not null then return result; end if;
  end loop;
  return null;
end
$$ language 'plpgsql' stable;





