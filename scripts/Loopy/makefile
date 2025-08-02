SHELL = cmd.exe
ifndef nzogps_base
$(error nzogps_base environment variable not set - run setlocals first)
endif

.SUFFIXES:
.SECONDARY:
TILES = Northland Southland Tasman Waikato Central Wellington Canterbury Auckland

BASE = $(subst ",,$(nzogps_base))
DLOAD = $(subst ",,$(nzogps_download))
OUTPUTS = outputs
SQL = sql

PSQL = $(nzogps_psql_bin)
RUBY = $(nzogps_ruby_cmd)
PERL = $(nzogps_perl_cmd)
PSQLC = $(PSQL)\psql -U postgres -d nzopengps

lc = $(subst A,a,$(subst B,b,$(subst C,c,$(subst D,d,$(subst E,e,$(subst F,f,$(subst G,g,$(subst H,h,$(subst I,i,$(subst J,j,$(subst K,k,$(subst L,l,$(subst M,m,$(subst N,n,$(subst O,o,$(subst P,p,$(subst Q,q,$(subst R,r,$(subst S,s,$(subst T,t,$(subst U,u,$(subst V,v,$(subst W,w,$(subst X,x,$(subst Y,y,$(subst Z,z,$1))))))))))))))))))))))))))

all : $(addprefix $(OUTPUTS)/, $(addsuffix -loops.csv, $(TILES)))
.PHONY: all

$(OUTPUTS)/%-loops.csv : $(SQL)/%_numberlines.sql
	$(PSQLC) -f $(call lc,$(<))
	$(PSQLC) -v linestable=$(call lc,$(*))_numberlines -v nodedtable=$(call lc,$(*))_noded_loops -v outfile='$(CURDIR)/$@' -f loopy.sql

$(SQL)/%_numberlines.sql : $(BASE)/%.mp
	cd $(SQL) &	$(PERL) ..\..\wrongside\mp_2_n_sql2.pl $(call lc,$(<))

