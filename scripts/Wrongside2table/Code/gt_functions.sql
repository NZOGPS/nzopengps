CREATE OR REPLACE FUNCTION gt_within(number integer, start integer, last integer, type character varying)
  RETURNS boolean AS
$BODY$
DECLARE 
	ret boolean;
	n1 integer;
	n2 integer;
	
BEGIN
	if last >= start then
		n1 = start;
		n2 = last;
	else
		n2 = start;
		n1 = last;	
	end if;
	if type = 'N' then
		return FALSE;
	end if;
	if type = 'E' then
		if mod(number,2)=1 then
			return FALSE;
		end if;
		if number/2 between n1/2 and n2/2 then
			return TRUE;
		else
			return FALSE;
		end if;
	end if;
	if type = 'O' then
		if mod(number,2)=0 then
			return FALSE;
		end if;
		if (number-1)/2 between (n1-1)/2 and (n2-1)/2 then
			return TRUE;
		else
			return FALSE;
		end if;
	end if;
	if type = 'B' then
		if number between n1 and n2 then
			return TRUE;
		else
			return FALSE;
		end if;
	end if;
END;
$BODY$
  LANGUAGE plpgsql

create or replace function gt_distance(number integer, side integer, n1 integer, n2 integer) returns double precision as $$	
DECLARE
	nx double precision;
	str text;
BEGIN
	if n1 = n2 then
		return 0.5;
	end if;
	nx = (number - n1)::double precision/(n2-n1)::double precision;
	if nx > 1 then
--		str = 'nx: '|| nx||' n1: '||n1||' n2: '||n2||' number: '||number;
--		raise notice 'nx greater than 1: %',str;
		return 1;
	end if;
	if nx < 0 then
--		str = 'nx: '|| nx||' n1: '||n1||' n2: '||n2||' number: '||number;
--		raise notice 'nx less than 0: %',str;
		return 0;
	end if;
	return nx;
	
END;
$$ language plpgsql;

