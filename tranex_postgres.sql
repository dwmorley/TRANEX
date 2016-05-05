-- ###################################################
-- ## Copyright 2014-15 David Morley
-- ## 
-- ## Licensed under the Apache License, Version 2.0 (the "License");
-- ## you may not use this file except in compliance with the License.
-- ## You may obtain a copy of the License at
-- ## 
-- ##     http://www.apache.org/licenses/LICENSE-2.0
-- ## 
-- ## Unless required by applicable law or agreed to in writing, software
-- ## distributed under the License is distributed on an "AS IS" BASIS,
-- ## WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- ## See the License for the specific language governing permissions and
-- ## limitations under the License.
-- ###################################################
-- ###################################################
-- ## TRANEX Road Traffic Noise Model
-- ## Version 1.3
-- ##
-- ## For instructions see the ReadMe
-- ## 
-- ## For reference see:
-- ##
-- ## John Gulliver, David Morley, Danielle Vienneau, Federico Fabbri, Margaret Bell, 
-- ## Paul Goodman, Sean Beevers, David Dajnak, Frank J Kelly, Daniela Fecht, 
-- ## Development of an open-source road traffic noise model for exposure assessment, 
-- ## Environmental Modelling & Software 
-- ## Available online 8 January 2015, 
-- ## ISSN 1364-8152, http://dx.doi.org/10.1016/j.envsoft.2014.12.022.
-- ## (http://www.sciencedirect.com/science/article/pii/S136481521400379X)
-- ##
-- ## MRC-PHE Centre for Environment and Health 
-- ## Department of Epidemiology and Biostatistics
-- ## School of Public Health, Faculty of Medicine
-- ## Imperial College London, UK
-- ## 
-- ## Contact:    			 
-- ## David Morley: d.morley@imperial.ac.uk	 
-- ###################################################

--Run this script in postgres to create the required functions in the database

--########################
--## SPATIAL FUNCTIONS  ##
--########################

--Take one row of the input receptors to process this iteration
create or replace function get_house(iid integer, receptor text, rec_id text)
returns integer as $$
declare 
begin
	execute '
	insert into this_point
	select r.geom, r.' || rec_id || ' as rec_id from '
	|| receptor || ' as r
	where gid = ' || iid;
	return iid;
end
$$ language 'plpgsql' volatile;

--Main CRTN model call
create or replace function do_crtn(road_points text, landcover text, traffic text)
returns double precision as $$
declare 
	refl double precision;
	rc integer;
	laeq16 double precision;
begin
	--get rays at 0.5km
	execute '
	insert into rays
	select r.rd_node_id as rd_node_id, st_makeline(pr.geom, r.geom) as geom,
	st_distance(pr.geom, r.geom) as totlen
	from ' || road_points || ' as r, this_point as pr
	where st_dwithin(pr.geom, r.geom, 500)';

	--if no roads, go to 1km buffer
	select count(*) from rays into rc; 
	if rc = 0 then
		execute '
		insert into rays
		select r.rd_node_id as rd_node_id, st_makeline(pr.geom, r.geom) as geom,
		st_distance(pr.geom, r.geom) as totlen
		from ' || road_points || ' as r, this_point as pr
		where st_dwithin(pr.geom, r.geom, 1000)';
		raise notice '%', '#### CREATED RAYS 1000m';
	else 
		raise notice '%', '#### CREATED RAYS 500m';
	end if;

	--get rays broken on landmap
	execute '
	insert into m_rays
	with os as (
		select r.ray, st_endpoint(r.geom) as s,
		(st_dump(st_intersection(r.geom, mm.geom))).geom as geom,
		mm.legend, mm.hgt as hgt, r.totlen
		from rays as r,' || landcover || ' as mm
		where st_intersects(r.geom, mm.geom)
	)
	select os.ray, os.geom, os.hgt, l.absorb, l.barrier, os.totlen,
	st_length(os.geom) as shape_length, st_distance(os.s, st_endpoint(os.geom)) as near_dist
	from os left join lut as l
	on os.legend = l.legend';

	--get delta corrections and traffic flows
	--deltatd (road surface) is a constant here
	execute '
	insert into noise_params
	select (noise1).*, noise2.a from 
	(select t1.*, t2.deltagc, -1 as deltatd 
	from 
	(select r.ray,
	get_l10hr(n.q_0) as l10hr_0, 
	get_l10hr(n.q_1) as l10hr_1,
	get_l10hr(n.q_2) as l10hr_2,
	get_l10hr(n.q_3) as l10hr_3,
	get_l10hr(n.q_4) as l10hr_4,
	get_l10hr(n.q_5) as l10hr_5,
	get_l10hr(n.q_6) as l10hr_6,
	get_l10hr(n.q_7) as l10hr_7,
	get_l10hr(n.q_8) as l10hr_8,
	get_l10hr(n.q_9) as l10hr_9,
	get_l10hr(n.q_10) as l10hr_10,
	get_l10hr(n.q_11) as l10hr_11,
	get_l10hr(n.q_12) as l10hr_12,
	get_l10hr(n.q_13) as l10hr_13,
	get_l10hr(n.q_14) as l10hr_14,
	get_l10hr(n.q_15) as l10hr_15,
	get_l10hr(n.q_16) as l10hr_16,
	get_l10hr(n.q_17) as l10hr_17,
	get_l10hr(n.q_18) as l10hr_18,
	get_l10hr(n.q_19) as l10hr_19,
	get_l10hr(n.q_20) as l10hr_20,
	get_l10hr(n.q_21) as l10hr_21,
	get_l10hr(n.q_22) as l10hr_22,
	get_l10hr(n.q_23) as l10hr_23,
	get_deltapv(n.q_0, n.p_0, n.v_0, n.slope_per) as deltapv_0,
	get_deltapv(n.q_1, n.p_1, n.v_1, n.slope_per) as deltapv_1,
	get_deltapv(n.q_2, n.p_2, n.v_2, n.slope_per) as deltapv_2,
	get_deltapv(n.q_3, n.p_3, n.v_3, n.slope_per) as deltapv_3,
	get_deltapv(n.q_4, n.p_4, n.v_4, n.slope_per) as deltapv_4,
	get_deltapv(n.q_5, n.p_5, n.v_5, n.slope_per) as deltapv_5,
	get_deltapv(n.q_6, n.p_6, n.v_6, n.slope_per) as deltapv_6,
	get_deltapv(n.q_7, n.p_7, n.v_7, n.slope_per) as deltapv_7,
	get_deltapv(n.q_8, n.p_8, n.v_8, n.slope_per) as deltapv_8,
	get_deltapv(n.q_9, n.p_9, n.v_9, n.slope_per) as deltapv_9,
	get_deltapv(n.q_10, n.p_10, n.v_10, n.slope_per) as deltapv_10,
	get_deltapv(n.q_11, n.p_11, n.v_11, n.slope_per) as deltapv_11,
	get_deltapv(n.q_12, n.p_12, n.v_12, n.slope_per) as deltapv_12,
	get_deltapv(n.q_13, n.p_13, n.v_13, n.slope_per) as deltapv_13,
	get_deltapv(n.q_14, n.p_14, n.v_14, n.slope_per) as deltapv_14,
	get_deltapv(n.q_15, n.p_15, n.v_15, n.slope_per) as deltapv_15,
	get_deltapv(n.q_16, n.p_16, n.v_16, n.slope_per) as deltapv_16,
	get_deltapv(n.q_17, n.p_17, n.v_17, n.slope_per) as deltapv_17,
	get_deltapv(n.q_18, n.p_18, n.v_18, n.slope_per) as deltapv_18,
	get_deltapv(n.q_19, n.p_19, n.v_19, n.slope_per) as deltapv_19,
	get_deltapv(n.q_20, n.p_20, n.v_20, n.slope_per) as deltapv_20,
	get_deltapv(n.q_21, n.p_21, n.v_21, n.slope_per) as deltapv_21,
	get_deltapv(n.q_22, n.p_22, n.v_22, n.slope_per) as deltapv_22,
	get_deltapv(n.q_23, n.p_23, n.v_23, n.slope_per) as deltapv_23,
	get_deltad(r.totlen) as deltad,
	get_deltaav(r.totlen) as deltaav, 
	get_deltag(n.slope_per) as deltag
	from rays as r left join '|| traffic ||' as n 
	on n.rd_node_id = r.rd_node_id) as t1
	left join
	(with abd as (
		select r.ray, sum(r.shape_length) as abs_length, r.totlen
		from m_rays as r 
		where r.absorb = 1
		group by r.ray, r.totlen
	)
	select a.ray, get_deltagc(a.totlen, a.abs_length) as deltagc
	from abd as a) as t2
	on t1.ray = t2.ray) as noise1
	left join
	(with bv as (
		with at_max as (
			with h as (
				select r.ray, max(r.hgt) as hgt_max
				from m_rays as r
				where r.barrier = 1
				group by r.ray
			)
			select h.hgt_max, mr.near_dist, mr.ray, mr.totlen 
			from m_rays as mr left join h
			on mr.ray = h.ray
			where mr.hgt = h.hgt_max
		)
		select min(a.near_dist) as near, 
		a.hgt_max, a.ray, a.totlen
		from at_max as a 
		group by a.hgt_max, a.ray, a.totlen
	)
	select b.ray, get_barriercorrection(b.hgt_max, b.totlen, b.near) as a
	from bv as b) as noise2
	on noise1.ray = noise2.ray';

	--get reflections
	insert into selnode1
	select v.node_id, n.block_id, n.geom
	from vs_nodes as v left join node_set as n
	on n.node_id = v.node_id;
	
	refl := get_deltaof();
	if refl is null then
		refl := 0;
	end if;

	raise notice '%: %', '#### REFLECTIONS', refl;

	--do final noise calculation
	insert into noise 
	with h as (
		select p.rec_id as rec_id, --1200 / 2 = 600 cars
		get_laeq1h(sum(o.l10i_lg_0), 20.58573858) as laeq1h_0,
		get_laeq1h(sum(o.l10i_lg_1), 12.88543917) as laeq1h_1,
		get_laeq1h(sum(o.l10i_lg_2), 9.215678797) as laeq1h_2,
		get_laeq1h(sum(o.l10i_lg_3), 8.131071867) as laeq1h_3,
		get_laeq1h(sum(o.l10i_lg_4), 10.34589858) as laeq1h_4,
		get_laeq1h(sum(o.l10i_lg_5), 20.18681712) as laeq1h_5,
		get_laeq1h(sum(o.l10i_lg_6), 40.81193012) as laeq1h_6,
		get_laeq1h(sum(o.l10i_lg_7), 64.41245344) as laeq1h_7,
		get_laeq1h(sum(o.l10i_lg_8), 70.06107382) as laeq1h_8,
		get_laeq1h(sum(o.l10i_lg_9), 66.14501089) as laeq1h_9,
		get_laeq1h(sum(o.l10i_lg_10), 64.22094032) as laeq1h_10,
		get_laeq1h(sum(o.l10i_lg_11), 67.78001446) as laeq1h_11,
		get_laeq1h(sum(o.l10i_lg_12), 67.78001446) as laeq1h_12,
		get_laeq1h(sum(o.l10i_lg_13), 68.61541075) as laeq1h_13,
		get_laeq1h(sum(o.l10i_lg_14), 69.24430145) as laeq1h_14,
		get_laeq1h(sum(o.l10i_lg_15), 72.24949315) as laeq1h_15,
		get_laeq1h(sum(o.l10i_lg_16), 75.75622615) as laeq1h_16,
		get_laeq1h(sum(o.l10i_lg_17), 78.47807947) as laeq1h_17,
		get_laeq1h(sum(o.l10i_lg_18), 74.35388118) as laeq1h_18,
		get_laeq1h(sum(o.l10i_lg_19), 67.1441847) as laeq1h_19,
		get_laeq1h(sum(o.l10i_lg_20), 55.06170622) as laeq1h_20,
		get_laeq1h(sum(o.l10i_lg_21), 46.31995043) as laeq1h_21,
		get_laeq1h(sum(o.l10i_lg_22), 39.94398218) as laeq1h_22,
		get_laeq1h(sum(o.l10i_lg_23), 30.84281018) as laeq1h_23
		from (select 
		get_noise(b.l10hr_0, b.deltapv_0, b.deltag, b.deltatd, b.deltad, b.deltaav, coalesce(b.a, 0), coalesce(b.deltagc, 0), refl) as l10i_lg_0,
		get_noise(b.l10hr_1, b.deltapv_1, b.deltag, b.deltatd, b.deltad, b.deltaav, coalesce(b.a, 0), coalesce(b.deltagc, 0), refl) as l10i_lg_1,
		get_noise(b.l10hr_2, b.deltapv_2, b.deltag, b.deltatd, b.deltad, b.deltaav, coalesce(b.a, 0), coalesce(b.deltagc, 0), refl) as l10i_lg_2,
		get_noise(b.l10hr_3, b.deltapv_3, b.deltag, b.deltatd, b.deltad, b.deltaav, coalesce(b.a, 0), coalesce(b.deltagc, 0), refl) as l10i_lg_3,
		get_noise(b.l10hr_4, b.deltapv_4, b.deltag, b.deltatd, b.deltad, b.deltaav, coalesce(b.a, 0), coalesce(b.deltagc, 0), refl) as l10i_lg_4,
		get_noise(b.l10hr_5, b.deltapv_5, b.deltag, b.deltatd, b.deltad, b.deltaav, coalesce(b.a, 0), coalesce(b.deltagc, 0), refl) as l10i_lg_5,
		get_noise(b.l10hr_6, b.deltapv_6, b.deltag, b.deltatd, b.deltad, b.deltaav, coalesce(b.a, 0), coalesce(b.deltagc, 0), refl) as l10i_lg_6,
		get_noise(b.l10hr_7, b.deltapv_7, b.deltag, b.deltatd, b.deltad, b.deltaav, coalesce(b.a, 0), coalesce(b.deltagc, 0), refl) as l10i_lg_7,
		get_noise(b.l10hr_8, b.deltapv_8, b.deltag, b.deltatd, b.deltad, b.deltaav, coalesce(b.a, 0), coalesce(b.deltagc, 0), refl) as l10i_lg_8,
		get_noise(b.l10hr_9, b.deltapv_9, b.deltag, b.deltatd, b.deltad, b.deltaav, coalesce(b.a, 0), coalesce(b.deltagc, 0), refl) as l10i_lg_9,
		get_noise(b.l10hr_10, b.deltapv_10, b.deltag, b.deltatd, b.deltad, b.deltaav, coalesce(b.a, 0), coalesce(b.deltagc, 0), refl) as l10i_lg_10,
		get_noise(b.l10hr_11, b.deltapv_11, b.deltag, b.deltatd, b.deltad, b.deltaav, coalesce(b.a, 0), coalesce(b.deltagc, 0), refl) as l10i_lg_11,
		get_noise(b.l10hr_12, b.deltapv_12, b.deltag, b.deltatd, b.deltad, b.deltaav, coalesce(b.a, 0), coalesce(b.deltagc, 0), refl) as l10i_lg_12,
		get_noise(b.l10hr_13, b.deltapv_13, b.deltag, b.deltatd, b.deltad, b.deltaav, coalesce(b.a, 0), coalesce(b.deltagc, 0), refl) as l10i_lg_13,
		get_noise(b.l10hr_14, b.deltapv_14, b.deltag, b.deltatd, b.deltad, b.deltaav, coalesce(b.a, 0), coalesce(b.deltagc, 0), refl) as l10i_lg_14,
		get_noise(b.l10hr_15, b.deltapv_15, b.deltag, b.deltatd, b.deltad, b.deltaav, coalesce(b.a, 0), coalesce(b.deltagc, 0), refl) as l10i_lg_15,
		get_noise(b.l10hr_16, b.deltapv_16, b.deltag, b.deltatd, b.deltad, b.deltaav, coalesce(b.a, 0), coalesce(b.deltagc, 0), refl) as l10i_lg_16,
		get_noise(b.l10hr_17, b.deltapv_17, b.deltag, b.deltatd, b.deltad, b.deltaav, coalesce(b.a, 0), coalesce(b.deltagc, 0), refl) as l10i_lg_17,
		get_noise(b.l10hr_18, b.deltapv_18, b.deltag, b.deltatd, b.deltad, b.deltaav, coalesce(b.a, 0), coalesce(b.deltagc, 0), refl) as l10i_lg_18,
		get_noise(b.l10hr_19, b.deltapv_19, b.deltag, b.deltatd, b.deltad, b.deltaav, coalesce(b.a, 0), coalesce(b.deltagc, 0), refl) as l10i_lg_19,
		get_noise(b.l10hr_20, b.deltapv_21, b.deltag, b.deltatd, b.deltad, b.deltaav, coalesce(b.a, 0), coalesce(b.deltagc, 0), refl) as l10i_lg_20,
		get_noise(b.l10hr_21, b.deltapv_21, b.deltag, b.deltatd, b.deltad, b.deltaav, coalesce(b.a, 0), coalesce(b.deltagc, 0), refl) as l10i_lg_21,
		get_noise(b.l10hr_22, b.deltapv_22, b.deltag, b.deltatd, b.deltad, b.deltaav, coalesce(b.a, 0), coalesce(b.deltagc, 0), refl) as l10i_lg_22,
		get_noise(b.l10hr_23, b.deltapv_23, b.deltag, b.deltatd, b.deltad, b.deltaav, coalesce(b.a, 0), coalesce(b.deltagc, 0), refl) as l10i_lg_23
		from noise_params as b) as o, this_point as p
		group by p.rec_id
	)
	select rec_id, 
	--hourly predictions
	laeq1h_0, laeq1h_1, laeq1h_2, laeq1h_3, laeq1h_4, laeq1h_5, laeq1h_6, 
	laeq1h_7, laeq1h_8, laeq1h_9, laeq1h_10, laeq1h_11, laeq1h_12, 
	laeq1h_13, laeq1h_14, laeq1h_15, laeq1h_16, laeq1h_17, laeq1h_18, 
	laeq1h_19, laeq1h_20, laeq1h_21, laeq1h_22, laeq1h_23,
	--day
	10 * log(((10 ^ (laeq1h_7 / 10)) + (10 ^ (laeq1h_8 / 10)) + (10 ^ (laeq1h_9 / 10)) + (10 ^ (laeq1h_10 / 10)) + (10 ^ (laeq1h_11 / 10)) +
	(10 ^ (laeq1h_12 / 10)) + (10 ^ (laeq1h_13 / 10)) + (10 ^ (laeq1h_14 / 10)) + (10 ^ (laeq1h_15 / 10)) + (10 ^ (laeq1h_16 / 10)) + 
	(10 ^ (laeq1h_17 / 10)) + (10 ^ (laeq1h_18 / 10))) / 12) as lday,
	--evening
	10 * log(((10 ^ (laeq1h_19 / 10)) + (10 ^ (laeq1h_20 / 10)) + (10 ^ (laeq1h_21 / 10)) + (10 ^ (laeq1h_22 / 10))) / 4) as leve,
	--night
	10 * log(((10 ^ (laeq1h_23 / 10)) + (10 ^ (laeq1h_0 / 10)) + (10 ^ (laeq1h_1 / 10)) + (10 ^ (laeq1h_2 / 10)) +
	(10 ^ (laeq1h_3 / 10)) + (10 ^ (laeq1h_4 / 10)) + (10 ^ (laeq1h_5 / 10)) + (10 ^ (laeq1h_6 / 10))) / 8) as lnight,
	--laeq16
	10 * log(((10 ^ (laeq1h_7 / 10)) + (10 ^ (laeq1h_8 / 10)) + (10 ^ (laeq1h_9 / 10)) + (10 ^ (laeq1h_10 / 10)) + (10 ^ (laeq1h_11 / 10)) +
	(10 ^ (laeq1h_12 / 10)) + (10 ^ (laeq1h_13 / 10)) + (10 ^ (laeq1h_14 / 10)) + (10 ^ (laeq1h_15 / 10)) + (10 ^ (laeq1h_16 / 10)) + 
	(10 ^ (laeq1h_17 / 10)) + (10 ^ (laeq1h_18 / 10)) + (10 ^ (laeq1h_19 / 10)) + (10 ^ (laeq1h_20 / 10)) + (10 ^ (laeq1h_21 / 10)) +
	(10 ^ (laeq1h_22 / 10))) / 16) as laeq16,
	--lden
	10 * log(((12 * (10 ^ (((10 * log(((10 ^ (laeq1h_7 / 10)) + (10 ^ (laeq1h_8 / 10)) + (10 ^ (laeq1h_9 / 10)) + (10 ^ (laeq1h_10 / 10)) + (10 ^ (laeq1h_11 / 10)) +
	(10 ^ (laeq1h_12 / 10)) + (10 ^ (laeq1h_13 / 10)) + (10 ^ (laeq1h_14 / 10)) + (10 ^ (laeq1h_15 / 10)) + (10 ^ (laeq1h_16 / 10)) + 
	(10 ^ (laeq1h_17 / 10)) + (10 ^ (laeq1h_18 / 10))) / 12)) / 12) / 10))) + (4 * (10 ^ (((10 * log(((10 ^ (laeq1h_19 / 10)) 
	+ (10 ^ (laeq1h_20 / 10)) + (10 ^ (laeq1h_21 / 10)) + (10 ^ (laeq1h_22 / 10))) / 4)) + 5) / 10))) + 
	(8 * (10 ^ (((10 * log(((10 ^ (laeq1h_23 / 10)) + (10 ^ (laeq1h_0 / 10)) + (10 ^ (laeq1h_1 / 10)) + (10 ^ (laeq1h_2 / 10)) +
	(10 ^ (laeq1h_3 / 10)) + (10 ^ (laeq1h_4 / 10)) + (10 ^ (laeq1h_5 / 10)) + (10 ^ (laeq1h_6 / 10))) / 8)) + 10) / 10)))) / 24) as lden
	from h;

	--report laeq16
	select t.laeq16 from noise as t, this_point as p where t.rec_id = p.rec_id into laeq16;
	
	--clear tables
	truncate rays;
	truncate m_rays;
	truncate noise_params;
	truncate build_hc;
	truncate selnode1;
	truncate node_set;
	truncate this_point;
	
	return laeq16;
end
$$ language 'plpgsql' volatile;

--###########################
--## REFLECTIONS FUNCTIONS ##
--###########################

--Get AOI from building heights raster for viewshed
create or replace function get_rastersubset(heights text, nodes text)
returns integer as $$
declare 
	buf geometry;
begin
	--clip heights raster to 50m buffer
 	select st_buffer(p.geom, 50) as geom
 	from this_point as p into buf;

	execute '
	insert into build_hc
	with c as (
		select (gv).geom as geom, (gv).val
		from 
		(select st_intersection(rast, cast(''' || cast(buf as text) || ''' as geometry)) as gv
		from ' || heights || '
		where st_intersects(rast, cast(''' || cast(buf as text) || ''' as geometry))
		) as f
	)
	select (st_dump(st_buffer(c.geom, 0.0))).geom as geom, c.val
	from c';

	--clip nodes points
	execute '
	insert into node_set
	select n.node_id, n.block_id, n.geom
	from ' || nodes || ' as n
	where st_intersects(cast(''' || cast(buf as text) || ''' as geometry), n.geom)';
	
	return (1);
end
$$ language 'plpgsql' volatile;

--Get all angles to buildings in viewshed
create or replace function get_deltaof()
returns double precision as $$
declare 
	delta double precision;
	numerator double precision;
	--constant denumerator
	--(not part of official CRTN)
	denumerator double precision := 180;
	rec geometry;
begin	
	select pr.geom from this_point as pr into rec;
	--get node bearings and quads
	insert into inputr
	with brgs as (
		with offblk as (
			with near as (
				--remove block the receptor is on
				select distinct nnid(rec, 100, 2, 100, 'selnode1', 'block_id', 'geom') as idn
				from selnode1 as s
			)
			select s.node_id, 270 - degrees(st_azimuth(rec, s.geom)) as near_angle, s.block_id from
			selnode1 as s, near as n
			where s.block_id <> n.idn
		)
		select o.*, get_quad(o.near_angle) as quad, get_bearing(o.near_angle) as bearing
		from offblk as o 
	)
	select b.*, get_adjbearing(b.bearing) as adjbearing
	from brgs as b;

	--max,min and bearings for each node
	insert into allbearing
	select r.*, get_stbearing(q.squad_min, q.squad_max, r.bearing, r.adjbearing) as sbearing,
	get_stbearing(q.tquad_min, q.tquad_max, r.bearing, r.adjbearing) as tbearing
	from inputr as r left join 
	(select r.block_id, max(quad) as squad_max , min(quad) as squad_min, t.tquad_max, t.tquad_min
	from inputr as r, 
	(select max(quad) as tquad_max , min(quad) as tquad_min
	from inputr as r) as t
	group by r.block_id, t.tquad_max, t.tquad_min) as q
	on r.block_id = q.block_id;

	--segment angles: numerator
	with blks as (
		with minmax as (
			select a.block_id, min(a.sbearing) as sbearing_min,
			max(a.sbearing) as sbearing_max
			from allbearing as a
			group by a.block_id
		)
		select mn.node_min, mx.node_max, mx.sbearing_max, mn.sbearing_min, mn.block_id, 
		mn.geom as geom_min, mx.geom as geom_max
		from 
			(select a.node_id as node_min, a.block_id, m.sbearing_min, s.geom
			from minmax as m, allbearing as a left join selnode1 as s
			on s.node_id = a.node_id
			where m.sbearing_min = a.sbearing) as mn
		left join
			(select a.node_id as node_max, a.block_id, m.sbearing_max, s.geom
			from minmax as m, allbearing as a left join selnode1 as s
			on s.node_id = a.node_id
			where m.sbearing_max = a.sbearing) as mx
		on mx.block_id = mn.block_id
	)
	select sum(get_segangle(rec, b.geom_min, b.geom_max)) as seg_angle
	from blks as b into numerator;
	
	if numerator is null then
		return 0;
	end if;
	if numerator > 180 then
		numerator := 180;
	end if;
	delta := 1.5 * (numerator / denumerator);

	truncate inputr;
	truncate allbearing;
	
	return delta;
	end;
$$ language 'plpgsql' volatile;

--Get segment angle of individual buildings within viewshed
create or replace function get_segangle(rec geometry, node1 geometry, node2 geometry)
returns double precision as $$
declare 
	c double precision;
	seg double precision;
	aside double precision;
	bside double precision;
	cside double precision;
begin
	aside := st_distance(rec, node1);
	bside := st_distance(rec, node2);
	cside := st_distance(node2, node1);
	c := (aside ^ 2 + bside ^ 2 - cside ^ 2) / (2 * aside * bside);
	if c >= -1 and c <= 1 then
		seg := degrees(acos(c));
	end if;
	if seg is null then
		return null;
	elsif seg > 1 and seg < 175 then
		return seg;
	else 
		return null;
	end if;
	end;
$$ language 'plpgsql' stable;

--Get quadrant of angle of view bearings
create or replace function get_quad(a double precision)
returns integer as $$
declare 
	q integer;
begin
	if a < 0 and a > -90 then
		q := 1;
	elsif a <= -90 and a >= -180 then
		q := 2;
	elsif a >= 0 and a < 90 then
		q := 3;
	elsif a >= 90 and a <= 180 then
		q := 4;
	end if;
	return q;
	end;
$$ language 'plpgsql' stable;

--Get bearing (according to ArcGIS)
create or replace function get_bearing(a double precision)
returns double precision as $$
declare 
	b double precision;
begin
	if a >= 0 and a < 90 then
		b := 90 - a;
	elsif a >= 90 and a <= 180 then
		b := 450 - a;
	elsif a < 0 then
		b := abs(a) + 90;
	end if;
	return b;
	end;
$$ language 'plpgsql' stable;

--Adjust bearing (according to ArcGIS)
create or replace function get_adjbearing(a double precision)
returns double precision as $$
declare 
	b double precision;
begin
	if a >= 0 and a < 180 then
		b := a + 180; 
	elsif a >= 180 and a < 360 then
		b := a - 180;
	end if;
	return b;
	end;
$$ language 'plpgsql' stable;

create or replace function get_stbearing(sq_min integer, sq_max integer, brg double precision, abrg double precision)
returns double precision as $$
declare 
	b double precision;
begin
	if (sq_min = 1 and sq_max = 2) or (sq_min = 1 and sq_max = 3) then
		b := brg;
	else
		b := abrg;
	end if;
	return b;
	end;
$$ language 'plpgsql' stable;


--#####################
--## NOISE FUNCTIONS ##
--#####################

--noise calculations 
create or replace function get_noise(l10hr double precision, pv double precision, 
g double precision, td double precision, d double precision, av double precision, 
a double precision, gc double precision, ofs double precision)
returns double precision as $$
declare 
	l10i double precision;
begin
	if a < 0 then
		l10i := l10hr + pv + g + td + d + av + a + ofs; 
	elsif a = 0 then
		l10i := l10hr + pv + g + td + d + av + gc + ofs;
	end if;
	return  10 ^ (l10i / 10);
	end;
$$ language 'plpgsql' stable;

--get traffic flow
create or replace function get_l10hr(q double precision)
returns double precision as $$
declare 
	l10hr double precision;
begin
	if q <= 0 then 
		q := 1;
	end if;
	l10hr := 42.2 + (10 * log(q));
	return l10hr;
	end;
$$ language 'plpgsql' stable;

--Get laeq
create or replace function get_laeq1h(x double precision, minor double precision)
returns double precision as $$
declare 
	laeq double precision;
begin
	if x is null then
		x := 0;
	end if;
	--plus minor roads correction assuming x vehicles a day 
	--distributed according to average daily flow profile for London
	--(not part of official CRTN)	
	minor := minor / 2; --divide 1200 by 2 to get 600 cars a day
	--minor := 25; --600/24 constant flow

	x := x + (10 ^ (get_l10hr(minor) / 10));	
	laeq := (0.94 * (10 * log(x))) + 0.77; 
	return laeq;
	end;
$$ language 'plpgsql' stable;

--get heavy adjustment
create or replace function get_deltapv(q double precision, p double precision, v double precision, grad double precision)
returns double precision as $$
declare 
	adjv double precision; 
	delta double precision;
begin
	adjv := v - ((0.73 + (2.3 - ((1.15 * p) / 100)) * (p / 100)) * grad);
	delta := (33 * (log(adjv + 40 + (500 / adjv)))) + (10 * (log(1 + ((5 * p) / adjv)))) - 68.8;
	--Catching log errors, take 11 as max correction (not part of official CRTN)
	if delta > 11 then
		return 11;
	end if;
	return delta;
	exception 
	when invalid_argument_for_logarithm then
		return 11;
	when division_by_zero then
		return 11;
	end;
$$ language 'plpgsql' stable;

--ground cover correction
create or replace function get_deltagc(d double precision, ab double precision)
returns double precision as $$
declare 
	delta double precision;
	h double precision;
	htest double precision;
	pabsorb double precision;
	ivalue double precision;
begin
	h := 0.5 * (3.5 + 1);
	htest := (d  - 3.5 + 5) / 6;
	pabsorb := (ab / d);
	if pabsorb < 0.1 then
		ivalue := 0;
	elsif pabsorb >= 0.1 and pabsorb < 0.4 then
		ivalue := 0.25;
	elsif pabsorb >= 0.4 and pabsorb < 0.6 then
		ivalue := 0.5;
	elsif pabsorb >= 0.6 and pabsorb < 0.9 then
		ivalue := 0.75;
	elsif pabsorb >= 0.9 then
		ivalue := 1.0;
	end if;
	if h >= 0.75 and h < htest then
		delta := 5.2 * ivalue * (log(((6 * h) - 1.5) / d));
	end if;
	if h < 0.75 then
		delta := 5.2 * ivalue * (log(3 / d));
	end if;
	if h >= htest then
		delta := 0;
	end if;
	if (d - 3.5) < 4 then
		delta := 0;
	end if;
	return delta;
	end;
$$ language 'plpgsql' stable;

--gradient correction
create or replace function get_deltag(grad double precision)
returns double precision as $$
declare 
	delta double precision;
begin
	delta := 0.3 * grad;
	return delta;
	end;
$$ language 'plpgsql' stable;

--distance from source correction
create or replace function get_deltad(d double precision)
returns double precision as $$
declare 
	delta double precision;
begin
	if d - 3.5 >= 4 then
		delta := -10 * (log((sqrt((d ^ 2) + (3.5 ^ 2))) / 13.5 ));
	else
		delta := -10 * (log((sqrt((7.5 ^ 2) + (3.5 ^ 2))) / 13.5 ));
	end if;
	return delta;
	end;
$$ language 'plpgsql' stable;

--angle of view
create or replace function get_deltaav(d double precision)
returns double precision as $$
declare 
	delta double precision;
	avr double precision;
	av double precision;
begin
	avr := atan(10 / d);
	av := (avr * 57.2957795) * 2;
	delta := 10 * (log(av / 180));
	return delta;
	end;
$$ language 'plpgsql' stable;

--Barrier correction
create or replace function get_barriercorrection(h double precision, d double precision, near double precision)
returns double precision as $$
declare 
	a double precision;
	sb double precision;
	sr double precision;
	br double precision;
	x double precision;
begin
	--set h to 0.5 if small or negative
	if h < 0.5 then
		h := 0.5;
	end if;
	--path difference
	sb := sqrt((near ^ 2) + (h ^ 2));
	sr := sqrt(((d - 1)  ^ 2) + (3.5 ^ 2));
	if h >= 3.5 then
		br := sqrt(((d - 1 - near) ^ 2) + ((h - 3.5) ^ 2));
	else 
		br := sqrt(((d - 1 - near) ^ 2) + ((3.5 - h) ^ 2));
	end if;

	--calculate a 
	x := log(sb + br - sr);
	if h >= 3.5 then --in shadow zone
		if x >= -3 and x <= 1.2 then
			a := (-15.4+(-8.26 * x) + (-2.787 * (x ^ 2)) + (-0.831 * (x ^ 3)) + (-0.198 * (x ^ 4)) +
			(0.1539 * (x ^ 5)) + (0.12248 * (x ^ 6)) + (0.02175 * (x ^ 7)));
		elsif x < -3 then
			a := -5;
		elsif x > 1.2 then
			a := -30;
		end if;
	else --in illum zone
		if x >= -4 and x <= 0 then
			a := ((0.109 * x) + (-0.815 * (x ^ 2)) + (0.479 * (x ^ 3)) + (0.3284 * (x ^ 4)) + 
			(0.04385 * (x ^ 5)));
		elsif x < -4 then
			a := -5;
		elsif x > 0 then
			a := 0;
		end if;
	end if;
	return a;
	end;
$$ language 'plpgsql' stable;

--efficient nearest neighbour function
--http://gis.stackexchange.com/questions/14456/finding-the-closest-geometry-in-postgis
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


--#############
--## TABLES  ##
--#############

create or replace function make_tables()
returns integer as $$
declare 
begin
	drop table if exists this_point;
	drop table if exists rays;
	drop table if exists m_rays;
	drop table if exists noise_params;
	drop table if exists inputr;
	drop table if exists allbearing;
	drop table if exists build_hc;
	drop table if exists selnode1;
	drop table if exists node_set;
	drop table if exists vs_nodes;
	drop table if exists noise;
	
	create table this_point (
		geom geometry,
		rec_id integer
	);
	create table rays
	(
		rd_node_id integer,
		geom geometry,
		totlen double precision,
		ray serial
	);
	create index rays_indx on rays using gist(geom);
	create table m_rays
	(
		ray integer,
		geom geometry,
		hgt double precision,
		absorb smallint,
		barrier smallint,
		totlen double precision,
		shape_length double precision,
		near_dist double precision,
		fr_id serial
	);
	create index m_rays_indx on m_rays using gist(geom);
	create table noise_params
	(
		ray integer,
		l10hr_0 double precision,
		l10hr_1 double precision,
		l10hr_2 double precision,
		l10hr_3 double precision,
		l10hr_4 double precision,
		l10hr_5 double precision,
		l10hr_6 double precision,
		l10hr_7 double precision,
		l10hr_8 double precision,
		l10hr_9 double precision,
		l10hr_10 double precision,
		l10hr_11 double precision,
		l10hr_12 double precision,
		l10hr_13 double precision,
		l10hr_14 double precision,
		l10hr_15 double precision,
		l10hr_16 double precision,
		l10hr_17 double precision,
		l10hr_18 double precision,
		l10hr_19 double precision,
		l10hr_20 double precision,
		l10hr_21 double precision,
		l10hr_22 double precision,
		l10hr_23 double precision,
		deltapv_0 double precision,
		deltapv_1 double precision,
		deltapv_2 double precision,
		deltapv_3 double precision,
		deltapv_4 double precision,
		deltapv_5 double precision,
		deltapv_6 double precision,
		deltapv_7 double precision,
		deltapv_8 double precision,
		deltapv_9 double precision,
		deltapv_10 double precision,
		deltapv_11 double precision,
		deltapv_12 double precision,
		deltapv_13 double precision,
		deltapv_14 double precision,
		deltapv_15 double precision,
		deltapv_16 double precision,
		deltapv_17 double precision,
		deltapv_18 double precision,
		deltapv_19 double precision,
		deltapv_20 double precision,
		deltapv_21 double precision,
		deltapv_22 double precision,
		deltapv_23 double precision,
		deltad double precision,
		deltaav double precision,
		deltag double precision,
		deltagc double precision,
		deltatd double precision,
		a double precision
	);
	create table inputr
	(
		node_id integer,
		near_angle double precision,
		block_id integer,
		quad integer,
		bearing double precision,
		adjbearing double precision
	);
	create table allbearing
	(
		node_id integer,
		near_angle double precision,
		block_id integer,
		quad integer,
		bearing double precision,
		adjbearing double precision,
		sbearing double precision,
		tbearing double precision
	);
	create table build_hc
	(
		geom geometry,
		val double precision
	);
	create table selnode1
	(
		node_id integer,
		block_id integer,
		geom geometry
	);
	create table node_set
	(
		node_id integer,
		block_id integer,
		geom geometry
	);
	create table noise (
		rec_id integer,
		laeq1h_0 double precision,
		laeq1h_1 double precision,
		laeq1h_2 double precision,
		laeq1h_3 double precision,
		laeq1h_4 double precision,
		laeq1h_5 double precision,
		laeq1h_6 double precision,
		laeq1h_7 double precision,
		laeq1h_8 double precision,
		laeq1h_9 double precision,
		laeq1h_10 double precision,
		laeq1h_11 double precision,
		laeq1h_12 double precision,
		laeq1h_13 double precision,
		laeq1h_14 double precision,
		laeq1h_15 double precision,
		laeq1h_16 double precision,
		laeq1h_17 double precision,
		laeq1h_18 double precision,
		laeq1h_19 double precision,
		laeq1h_20 double precision,
		laeq1h_21 double precision,
		laeq1h_22 double precision,
		laeq1h_23 double precision,
		lday double precision,
		leve double precision,
		lnight double precision,
		laeq16 double precision,
		lden double precision
	);	
	return (1);
end
$$ language 'plpgsql' volatile;

--create look-up-table for mastermap
drop table if exists lut;
create table lut  
(
	legend text,
	absorb smallint, 
	barrier smallint
);
insert into lut values ('0000 Foreshore',1,0);
insert into lut values ('0000 Historic interest area',0,0);
insert into lut values ('0000 Manmade surface or step',0,0);
insert into lut values ('0000 Multiple surface (garde',1,0);
insert into lut values ('0000 Multiple surface (garden)',1,0);
insert into lut values ('0000 Natural surface',1,0);
insert into lut values ('0000 Path',0,0);
insert into lut values ('0000 Railway',0,0);
insert into lut values ('0000 Road',0,0);
insert into lut values ('0000 Road traffic calming',0,0);
insert into lut values ('0000 Structure',0,1);
insert into lut values ('0000 Tidal water',1,0);
insert into lut values ('0000 Track',0,0);
insert into lut values ('0000 Unclassified (or broken)',0,0);
insert into lut values ('0000 Unknown surface',0,0);
insert into lut values ('0321 Archway',0,1);
insert into lut values ('0321 Building',0,1);
insert into lut values ('0323 Glasshouse',0,1);
insert into lut values ('0377 Boulders',0,0);
insert into lut values ('0379 Coniferous trees',1,0);
insert into lut values ('0380 Coniferous – scattered',1,0);
insert into lut values ('0381 Coppice or osiers',1,0);
insert into lut values ('0382 Marsh reeds or saltmarsh',1,0);
insert into lut values ('0384 Nonconiferous trees',1,0);
insert into lut values ('0385 Nonconiferous – scattered',1,0);
insert into lut values ('0386 Orchard',1,0);
insert into lut values ('0387 Heath',1,0);
insert into lut values ('0388 Rock',0,0);
insert into lut values ('0390 Rough grassland',1,0);
insert into lut values ('0392 Scrub',1,0);
insert into lut values ('0395 Upper level communication',0,1);
insert into lut values ('0400 Inland water',1,0);
