select current_time;
update :numstable set asnum_roadid=:linestable.gid,asnum_side=-1,asnum_segment=nnum  from :linestable where  :numstable.rna_id = :linestable.linzid and gt_within(range_low::integer,lstart,lend,ltype) ;
update :numstable set asnum_roadid=:linestable.gid,asnum_side=1,asnum_segment=nnum  from :linestable where  :numstable.rna_id = :linestable.linzid and gt_within(range_low::integer,rstart,rend,rtype) ;
update :numstable set asnum_distance=gt_distance(range_low::integer,asnum_side,lstart,lend) from :linestable where :linestable.gid=asnum_roadid and asnum_side=-1;
update :numstable set asnum_distance=gt_distance(range_low::integer,asnum_side,rstart,rend) from :linestable where :linestable.gid=asnum_roadid and asnum_side=1;
update :numstable set asnum_position=ST_Line_Interpolate_Point(nztm_line,asnum_distance) from :linestable where :linestable.gid=asnum_roadid;
update :numstable set asnum_dist_err=ST_Distance(nztm,asnum_position);
update :numstable set isect_side=1, isect_roadid=:linestable.gid from :linestable where rna_id=linzid and ST_Intersects(nztm,rightpoly);
update :numstable set isect_side=-1, isect_roadid=:linestable.gid from :linestable where rna_id=linzid and ST_Intersects(nztm,leftpoly);
copy(select st_x(the_geom),st_y(the_geom),address,'Wrong Side: ' || id from :numstable where asnum_roadid = isect_roadid and asnum_side*isect_side=-1 order by id) to :outfile with CSV;
select current_time;