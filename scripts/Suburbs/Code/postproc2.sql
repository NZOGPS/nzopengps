
CREATE INDEX nzsl_idx ON nz_suburbs_and_localities USING btree(id);
CREATE INDEX nz_suburbs_and_localities_geom_idx ON public.nz_suburbs_and_localities USING gist(wkb_geometry);
CREATE INDEX nz_suburbs_and_localities_nztm_geom_idx ON public.nz_suburbs_and_localities USING gist(nztm_geometry);
