select current_time;
update :numstable set asnum_roadid=:linestable.gid,asnum_side=-1,asnum_segment=nnum  from :linestable where  :numstable.rna_id = :linestable.linzid and gt_within(address_number,lstart,lend,ltype) ;
update :numstable set asnum_roadid=:linestable.gid,asnum_side=1,asnum_segment=nnum  from :linestable where  :numstable.rna_id = :linestable.linzid and gt_within(address_number,rstart,rend,rtype) ;
update :numstable set asnum_distance=gt_distance(address_number,asnum_side,lstart,lend) from :linestable where :linestable.gid=asnum_roadid and asnum_side=-1;
update :numstable set asnum_distance=gt_distance(address_number,asnum_side,rstart,rend) from :linestable where :linestable.gid=asnum_roadid and asnum_side=1;
update :numstable set asnum_position=ST_LineInterpolatePoint(nztm_line,asnum_distance) from :linestable where :linestable.gid=asnum_roadid;
update :numstable set asnum_dist_err=ST_Distance(nztm,asnum_position);
update :numstable set isect_side=1, isect_roadid=:linestable.gid from :linestable where rna_id=linzid and ST_Intersects(nztm,rightpoly);
update :numstable set isect_side=-1, isect_roadid=:linestable.gid from :linestable where rna_id=linzid and ST_Intersects(nztm,leftpoly);
copy(select gd2000_xcoord,gd2000_ycoord,full_address_ascii,'Wrong Side: ' || address_id from :numstable where asnum_roadid = isect_roadid and asnum_side*isect_side=-1 order by address_id) to :outfile with CSV;
select current_time;
