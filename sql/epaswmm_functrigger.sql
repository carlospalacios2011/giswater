/*
This file is part of Giswater
The program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
This version of Giswater is provided by Giswater Association
*/

-----------------------------
-- TOPOLOGY ARC-NODE
-----------------------------

CREATE FUNCTION "SCHEMA_NAME".update_t_inp_arc_insert() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE 
	nodeRecord1 Record; 
	nodeRecord2 Record; 
	z1 double precision;
	z2 double precision;
 BEGIN 

	 SELECT * INTO nodeRecord1 FROM "SCHEMA_NAME".node node WHERE node.the_geom && ST_Expand(ST_startpoint(NEW.the_geom), 0.5)
		ORDER BY ST_Distance(node.the_geom, ST_startpoint(NEW.the_geom)) LIMIT 1;

	 SELECT * INTO nodeRecord2 FROM "SCHEMA_NAME".node node WHERE node.the_geom && ST_Expand(ST_endpoint(NEW.the_geom), 0.5)
		ORDER BY ST_Distance(node.the_geom, ST_endpoint(NEW.the_geom)) LIMIT 1;


--	Control de lineas de longitud 0
	IF (nodeRecord1.node_id IS NOT NULL) AND (nodeRecord2.node_id IS NOT NULL) THEN

		z1 = (nodeRecord1.top_elev - nodeRecord1.ymax + NEW.z1);
		z2 = (nodeRecord2.top_elev - nodeRecord2.ymax + NEW.z2);

		IF (z1 > z2) THEN

			NEW.node_1 := nodeRecord1.node_id; 
			NEW.node_2 := nodeRecord2.node_id;

		ELSE 

			NEW.the_geom := ST_reverse(NEW.the_geom);
			NEW.node_1 := nodeRecord2.node_id; 
			NEW.node_2 := nodeRecord1.node_id;

		END IF;

		RETURN NEW;

	ELSE
		RETURN NULL;
	END IF;

END; 
$$;

CREATE TRIGGER update_t_inp_insert_arc BEFORE INSERT OR UPDATE ON "SCHEMA_NAME"."arc"
FOR EACH ROW 
EXECUTE PROCEDURE "SCHEMA_NAME"."update_t_inp_arc_insert"();


CREATE FUNCTION "SCHEMA_NAME".update_t_inp_node_update() RETURNS trigger
    LANGUAGE plpgsql
    AS $_$DECLARE 
	querystring Varchar; 
	arcrec Record; 
	nodeRecord1 Record; 
	nodeRecord2 Record; 
	z1 double precision;
	z2 double precision;

BEGIN 

--	Select arcs with start-end on the updated node
	querystring := 'SELECT * FROM "SCHEMA_NAME"."arc" WHERE arc.node_1 = ' || quote_literal(NEW.node_id) || ' OR arc.node_2 = ' || quote_literal(NEW.node_id); 

	FOR arcrec IN EXECUTE querystring
	LOOP


--		Initial and final node of the arc
		SELECT * INTO nodeRecord1 FROM "SCHEMA_NAME"."node" node WHERE node.node_id = arcrec.node_1;
		SELECT * INTO nodeRecord2 FROM "SCHEMA_NAME"."node" node WHERE node.node_id = arcrec.node_2;


--		Control de lineas de longitud 0
		IF (nodeRecord1.node_id IS NOT NULL) AND (nodeRecord2.node_id IS NOT NULL) THEN


--			Update arc node coordinates, node_id and direction
			IF (nodeRecord1.node_id = NEW.node_id) THEN


--				Coordinates
				EXECUTE 'UPDATE "SCHEMA_NAME".arc SET the_geom = ST_SetPoint($1, 0, $2) WHERE arc_id = ' || quote_literal(arcrec."arc_id") USING arcrec.the_geom, NEW.the_geom; 


--				Search the upstream node
				z1 = (NEW.top_elev - NEW.ymax + arcrec.z1);
				z2 = (nodeRecord2.top_elev - nodeRecord2.ymax + arcrec.z2);

				IF (z2 > z1) THEN

					EXECUTE 'UPDATE "SCHEMA_NAME".arc SET node_1 = ' || quote_literal(nodeRecord2.node_id) || ', node_2 = ' || quote_literal(NEW.node_id) || ' WHERE arc_id = ' || quote_literal(arcrec."arc_id"); 
					EXECUTE 'UPDATE "SCHEMA_NAME".arc SET z1 = ' || arcrec.z2 || ', z2 = ' || arcrec.z1 || ' WHERE arc_id = ' || quote_literal(arcrec."arc_id"); 
					EXECUTE 'UPDATE "SCHEMA_NAME".arc SET the_geom = ST_reverse($1) WHERE arc_id = ' || quote_literal(arcrec."arc_id") USING arcrec.the_geom;
				END IF;
				
			ELSE


--				Coordinates
				EXECUTE 'UPDATE "SCHEMA_NAME".arc SET the_geom = ST_SetPoint($1, ST_NumPoints($1) - 1, $2) WHERE arc_id = ' || quote_literal(arcrec."arc_id") USING arcrec.the_geom, NEW.the_geom; 


--				Search the upstream node
				z1 = (nodeRecord1.top_elev - nodeRecord1.ymax + arcrec.z1);
				z2 = (NEW.top_elev - NEW.ymax + arcrec.z2);

				IF (z2 > z1) THEN

					EXECUTE 'UPDATE "SCHEMA_NAME".arc SET node_1 = ' || quote_literal(NEW.node_id) || ', node_2 = ' || quote_literal(nodeRecord1.node_id) || ' WHERE arc_id = ' || quote_literal(arcrec."arc_id"); 
					EXECUTE 'UPDATE "SCHEMA_NAME".arc SET z1 = ' || arcrec.z2 || ', z2 = ' || arcrec.z1 || ' WHERE arc_id = ' || quote_literal(arcrec."arc_id"); 
					EXECUTE 'UPDATE "SCHEMA_NAME".arc SET the_geom = ST_reverse($1) WHERE arc_id = ' || quote_literal(arcrec."arc_id") USING arcrec.the_geom;
				END IF;

			END IF;

		END IF;

	END LOOP; 

	RETURN NEW;


END; $_$;


CREATE TRIGGER update_t_inp_update_node AFTER UPDATE ON "SCHEMA_NAME"."node"
FOR EACH ROW 
EXECUTE PROCEDURE "SCHEMA_NAME"."update_t_inp_node_update"();


CREATE FUNCTION "SCHEMA_NAME".update_t_inp_node_delete() RETURNS trigger
    LANGUAGE plpgsql
    AS $$ --Function created modifying "tgg_functionborralinea" developed by Jose C. Martinez Llario
--in "PostGIS 2 Analisis Espacial Avanzado" 
 
DECLARE 
	querystring Varchar; 
	arcrec Record; 
	nodosactualizados Integer; 

BEGIN 
	nodosactualizados := 0; 
 
	querystring := 'SELECT arc.arc_id AS arc_id FROM "SCHEMA_NAME".arc WHERE arc.node_1 = ' || quote_literal(OLD.node_id) || ' OR arc.node_2 = ' || quote_literal(OLD.node_id); 

	FOR arcrec IN EXECUTE querystring
	LOOP
		EXECUTE 'DELETE FROM "SCHEMA_NAME".arc WHERE arc_id = ' || quote_literal(arcrec."arc_id"); 

	END LOOP; 

	RETURN OLD; 
END; 
$$;

CREATE TRIGGER update_t_inp_delete_node BEFORE DELETE ON "SCHEMA_NAME"."node"
FOR EACH ROW 
EXECUTE PROCEDURE "SCHEMA_NAME"."update_t_inp_node_delete"();

------------------------------------
--  EDITING VIEWS
------------------------------------


-- Function: SCHEMA_NAME.update_v_inp_edit_conduit()

CREATE OR REPLACE FUNCTION SCHEMA_NAME.update_v_inp_edit_conduit()
  RETURNS trigger AS
$BODY$
BEGIN
    IF TG_OP = 'INSERT' THEN
    INSERT INTO  SCHEMA_NAME.arc VALUES(NEW.arc_id,'', '', NEW.z1,NEW.z2,NEW.arccat_id,NEW.matcat_id,'CONDUIT'::TEXT,NEW.sector_id,NEW.the_geom);
		INSERT INTO  SCHEMA_NAME.inp_conduit VALUES(NEW.arc_id,NEW.barrels,NEW.culvert,NEW.kentry,NEW.kexit,NEW.kavg,NEW.flap,NEW.q0,NEW.qmax);
		RETURN NEW;
    ELSIF TG_OP = 'UPDATE' THEN
     UPDATE SCHEMA_NAME.arc SET arc_id=NEW.arc_id,z1=NEW.z1,z2=NEW.z2,arccat_id=NEW.arccat_id,matcat_id=NEW.matcat_id,sector_id=NEW.sector_id,the_geom=NEW.the_geom WHERE arc_id=OLD.arc_id;
	   UPDATE SCHEMA_NAME.inp_conduit SET arc_id=NEW.arc_id,barrels=NEW.barrels,culvert=NEW.culvert,kentry=NEW.kentry,kexit=NEW.kexit,kavg=NEW.kavg,flap=NEW.flap,q0=NEW.q0,qmax=NEW.qmax WHERE arc_id=OLD.arc_id;
       RETURN NEW;
    ELSIF TG_OP = 'DELETE' THEN
     DELETE FROM SCHEMA_NAME.arc WHERE arc_id=OLD.arc_id;
	   DELETE FROM SCHEMA_NAME.inp_conduit WHERE arc_id=OLD.arc_id;
	    RETURN NULL;
      END IF;
      RETURN NEW;
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;

  
CREATE TRIGGER "update_v_inp_edit_conduit" INSTEAD OF INSERT OR UPDATE OR DELETE ON "SCHEMA_NAME"."v_inp_edit_conduit"
FOR EACH ROW
EXECUTE PROCEDURE "SCHEMA_NAME"."update_v_inp_edit_conduit"();



  
-- Function: SCHEMA_NAME.update_v_inp_edit_divider()

CREATE OR REPLACE FUNCTION SCHEMA_NAME.update_v_inp_edit_divider()
  RETURNS trigger AS
$BODY$
BEGIN
    IF TG_OP = 'INSERT' THEN
    INSERT INTO  SCHEMA_NAME.node VALUES(NEW.node_id,NEW.top_elev,NEW.ymax,'DIVIDER'::TEXT,NEW.sector_id,NEW.the_geom);
		INSERT INTO  SCHEMA_NAME.inp_divider VALUES(NEW.node_id,NEW.divider_type,NEW.arc_id,NEW.curve_id,NEW.qmin,NEW.ht,NEW.cd,NEW.y0,NEW.ysur,NEW.apond);
		RETURN NEW;
    ELSIF TG_OP = 'UPDATE' THEN
     UPDATE SCHEMA_NAME.node SET node_id=NEW.node_id,top_elev=NEW.top_elev,elev=NEW.elev,ymax=NEW.ymax,sector_id=NEW.sector_id,the_geom=NEW.the_geom WHERE node_id=OLD.node_id;
	   UPDATE SCHEMA_NAME.inp_divider SET node_id=NEW.node_id, divider_type=NEW.divider_type, arc_id=NEW.arc_id, curve_id=NEW.curve_id,qmin=NEW.qmin,ht=NEW.ht,cd=NEW.cd,y0=NEW.y0, ysur=NEW.ysur, apond=NEW.apond WHERE node_id=OLD.node_id;
       RETURN NEW;
    ELSIF TG_OP = 'DELETE' THEN
     DELETE FROM SCHEMA_NAME.node WHERE node_id=OLD.node_id;
	   DELETE FROM SCHEMA_NAME.inp_divider WHERE node_id=OLD.node_id;
	    RETURN NULL;
      END IF;
      RETURN NEW;
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;

CREATE TRIGGER "update_v_inp_edit_divider" INSTEAD OF INSERT OR UPDATE OR DELETE ON "SCHEMA_NAME"."v_inp_edit_divider"
FOR EACH ROW
EXECUTE PROCEDURE "SCHEMA_NAME"."update_v_inp_edit_divider"();



  
-- Function: SCHEMA_NAME.update_v_inp_edit_junction()

CREATE OR REPLACE FUNCTION SCHEMA_NAME.update_v_inp_edit_junction()
  RETURNS trigger AS
$BODY$
BEGIN
    IF TG_OP = 'INSERT' THEN
    INSERT INTO  SCHEMA_NAME.node VALUES(NEW.node_id,NEW.top_elev,NEW.ymax,'JUNCTION'::TEXT,NEW.sector_id,NEW.the_geom);
		INSERT INTO  SCHEMA_NAME.inp_junction VALUES(NEW.node_id,NEW.y0,NEW.ysur,NEW.apond);
		RETURN NEW;
    ELSIF TG_OP = 'UPDATE' THEN
     UPDATE SCHEMA_NAME.node SET node_id=NEW.node_id,top_elev=NEW.top_elev,ymax=NEW.ymax,sector_id=NEW.sector_id,the_geom=NEW.the_geom WHERE node_id=OLD.node_id;
	   UPDATE SCHEMA_NAME.inp_junction SET node_id=NEW.node_id,y0=NEW.y0,ysur=NEW.ysur,apond=NEW.apond WHERE node_id=OLD.node_id;
       RETURN NEW;
    ELSIF TG_OP = 'DELETE' THEN
     DELETE FROM SCHEMA_NAME.node WHERE node_id=OLD.node_id;
	   DELETE FROM SCHEMA_NAME.inp_junction WHERE node_id=OLD.node_id;
	    RETURN NULL;
      END IF;
      RETURN NEW;
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;


CREATE TRIGGER "update_v_inp_edit_junction" INSTEAD OF INSERT OR UPDATE OR DELETE ON "SCHEMA_NAME"."v_inp_edit_junction"
FOR EACH ROW
EXECUTE PROCEDURE "SCHEMA_NAME"."update_v_inp_edit_junction"();



  
-- Function: SCHEMA_NAME.update_v_inp_edit_orifice()

CREATE OR REPLACE FUNCTION SCHEMA_NAME.update_v_inp_edit_orifice()
  RETURNS trigger AS
$BODY$
BEGIN
    IF TG_OP = 'INSERT' THEN
    INSERT INTO  SCHEMA_NAME.arc VALUES(NEW.arc_id,'','',NEW.z1,NEW.z2,DEFAULT,DEFAULT,'ORIFICE'::TEXT,NEW.sector_id,NEW.the_geom);
		INSERT INTO  SCHEMA_NAME.inp_orifice VALUES(NEW.arc_id,NEW.ori_type,NEW.offset,NEW.cd,NEW.orate,NEW.flap,NEW.shape,NEW.geom1,NEW.geom2,NEW.geom3,NEW.geom4);
		RETURN NEW;
    ELSIF TG_OP = 'UPDATE' THEN
     UPDATE SCHEMA_NAME.arc SET arc_id=NEW.arc_id,z1=NEW.z1,z2=NEW.z2,categ_type=NEW.categ_type,systm_type=NEW.systm_type,sector_id=NEW.sector_id,the_geom=NEW.the_geom WHERE arc_id=OLD.arc_id;
	   UPDATE SCHEMA_NAME.inp_orifice SET arc_id=NEW.arc_id,ori_type=NEW.ori_type,"offset"=NEW."offset",cd=NEW.cd,orate=NEW.orate,flap=NEW.flap,shape=NEW.shape,geom1=NEW.geom1,geom2=NEW.geom2,geom3=NEW.geom3,geom4=NEW.geom4 WHERE arc_id=OLD.arc_id;
       RETURN NEW;
    ELSIF TG_OP = 'DELETE' THEN
     DELETE FROM SCHEMA_NAME.arc WHERE arc_id=OLD.arc_id;
	   DELETE FROM SCHEMA_NAME.inp_orifice WHERE arc_id=OLD.arc_id;
	    RETURN NULL;
      END IF;
      RETURN NEW;
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;


CREATE TRIGGER "update_v_inp_edit_orifice" INSTEAD OF INSERT OR UPDATE OR DELETE ON "SCHEMA_NAME"."v_inp_edit_orifice"
FOR EACH ROW
EXECUTE PROCEDURE "SCHEMA_NAME"."update_v_inp_edit_orifice"();



  
-- Function: SCHEMA_NAME.update_v_inp_edit_outfall()

CREATE OR REPLACE FUNCTION SCHEMA_NAME.update_v_inp_edit_outfall()
  RETURNS trigger AS
$BODY$
BEGIN
    IF TG_OP = 'INSERT' THEN
    INSERT INTO  SCHEMA_NAME.node VALUES(NEW.node_id,NEW.top_elev,NEW.ymax,'OUTFALL'::TEXT,NEW.sector_id,NEW.the_geom);
		INSERT INTO  SCHEMA_NAME.inp_outfall VALUES(NEW.node_id,NEW.outfall_type,NEW.stage,NEW.curve_id,NEW.timser_id,NEW.gate);
		RETURN NEW;
    ELSIF TG_OP = 'UPDATE' THEN
     UPDATE SCHEMA_NAME.node SET node_id=NEW.node_id,top_elev=NEW.top_elev,ymax=NEW.ymax,sector_id=NEW.sector_id,the_geom=NEW.the_geom WHERE node_id=OLD.node_id;
	   UPDATE SCHEMA_NAME.inp_outfall SET node_id=NEW.node_id,outfall_type=NEW.outfall_type,stage=NEW.stage,curve_id=NEW.curve_id,timser_id=NEW.timser_id,gate=NEW.gate WHERE node_id=OLD.node_id;
       RETURN NEW;
    ELSIF TG_OP = 'DELETE' THEN
     DELETE FROM SCHEMA_NAME.node WHERE node_id=OLD.node_id;
	   DELETE FROM SCHEMA_NAME.inp_outfall WHERE node_id=OLD.node_id;
	    RETURN NULL;
      END IF;
      RETURN NEW;
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;


CREATE TRIGGER "update_v_inp_edit_outfall" INSTEAD OF INSERT OR UPDATE OR DELETE ON "SCHEMA_NAME"."v_inp_edit_outfall"
FOR EACH ROW
EXECUTE PROCEDURE "SCHEMA_NAME"."update_v_inp_edit_outfall"();



  
-- Function: SCHEMA_NAME.update_v_inp_edit_outlet()

CREATE OR REPLACE FUNCTION SCHEMA_NAME.update_v_inp_edit_outlet()
  RETURNS trigger AS
$BODY$
BEGIN
    IF TG_OP = 'INSERT' THEN
    INSERT INTO  SCHEMA_NAME.arc VALUES(NEW.arc_id,'','',NEW.z1,NEW.z2,DEFAULT,DEFAULT,'OUTLET'::TEXT,NEW.sector_id,NEW.the_geom);
		INSERT INTO  SCHEMA_NAME.inp_outlet VALUES(NEW.arc_id,NEW.outlet_type,NEW."offset",NEW.curve_id,NEW.cd1,NEW.cd2,NEW.flap);
		RETURN NEW;
    ELSIF TG_OP = 'UPDATE' THEN
     UPDATE SCHEMA_NAME.arc SET arc_id=NEW.arc_id,z1=NEW.z1,z2=NEW.z2,sector_id=NEW.sector_id,the_geom=NEW.the_geom WHERE arc_id=OLD.arc_id;
	   UPDATE SCHEMA_NAME.inp_outlet SET arc_id=NEW.arc_id,outlet_type=NEW.outlet_type,"offset"=NEW."offset",curve_id=NEW.curve_id,cd1=NEW.cd1,cd2=NEW.cd2,flap=NEW.flap WHERE arc_id=OLD.arc_id;
       RETURN NEW;
    ELSIF TG_OP = 'DELETE' THEN
     DELETE FROM SCHEMA_NAME.arc WHERE arc_id=OLD.arc_id;
	   DELETE FROM SCHEMA_NAME.inp_outlet WHERE arc_id=OLD.arc_id;
	    RETURN NULL;
      END IF;
      RETURN NEW;
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;


CREATE TRIGGER "update_v_inp_edit_outlet" INSTEAD OF INSERT OR UPDATE OR DELETE ON "SCHEMA_NAME"."v_inp_edit_outlet"
FOR EACH ROW
EXECUTE PROCEDURE "SCHEMA_NAME"."update_v_inp_edit_outlet"();



  
-- Function: SCHEMA_NAME.update_v_inp_edit_pump()

CREATE OR REPLACE FUNCTION SCHEMA_NAME.update_v_inp_edit_pump()
  RETURNS trigger AS
$BODY$
BEGIN
    IF TG_OP = 'INSERT' THEN
    INSERT INTO  SCHEMA_NAME.arc VALUES(NEW.arc_id,'','',NEW.z1,NEW.z2,DEFAULT,DEFAULT,'PUMP'::TEXT,NEW.sector_id,NEW.the_geom);
		INSERT INTO  SCHEMA_NAME.inp_pump VALUES(NEW.arc_id,NEW.curve_id,NEW.status,NEW.startup,NEW.shutoff);
		RETURN NEW;
    ELSIF TG_OP = 'UPDATE' THEN
     UPDATE SCHEMA_NAME.arc SET arc_id=NEW.arc_id,z1=NEW.z1,z2=NEW.z2,sector_id=NEW.sector_id,the_geom=NEW.the_geom WHERE arc_id=OLD.arc_id;
	   UPDATE SCHEMA_NAME.inp_pump SET arc_id=NEW.arc_id,curve_id=NEW.curve_id,status=NEW.status,startup=NEW.startup,shutoff=NEW.shutoff WHERE arc_id=OLD.arc_id;
       RETURN NEW;
    ELSIF TG_OP = 'DELETE' THEN
     DELETE FROM SCHEMA_NAME.arc WHERE arc_id=OLD.arc_id;
	   DELETE FROM SCHEMA_NAME.inp_pump WHERE arc_id=OLD.arc_id;
	    RETURN NULL;
      END IF;
      RETURN NEW;
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;


CREATE TRIGGER "update_v_inp_edit_pump" INSTEAD OF INSERT OR UPDATE OR DELETE ON "SCHEMA_NAME"."v_inp_edit_pump"
FOR EACH ROW
EXECUTE PROCEDURE "SCHEMA_NAME"."update_v_inp_edit_pump"();
  

  
--Function: SCHEMA_NAME.update_v_inp_edit_storage()

CREATE OR REPLACE FUNCTION SCHEMA_NAME.update_v_inp_edit_storage()
  RETURNS trigger AS
$BODY$
BEGIN
    IF TG_OP = 'INSERT' THEN
    INSERT INTO  SCHEMA_NAME.node VALUES(NEW.node_id,NEW.top_elev,NEW.ymax,'STORAGE'::TEXT,NEW.sector_id,NEW.the_geom);
		INSERT INTO  SCHEMA_NAME.inp_storage VALUES(NEW.node_id,NEW.storage_type,NEW.curve_id,NEW.a1,NEW.a2,NEW.a0,NEW.fevap,NEW.sh,NEW.hc,NEW.imd,NEW.y0,NEW.ysur,NEW.apond);
		RETURN NEW;
    ELSIF TG_OP = 'UPDATE' THEN
     UPDATE SCHEMA_NAME.node SET node_id=NEW.node_id,top_elev=NEW.top_elev,ymax=NEW.ymax,sector_id=NEW.sector_id,the_geom=NEW.the_geom WHERE node_id=OLD.node_id;
	   UPDATE SCHEMA_NAME.inp_storage SET node_id=NEW.node_id, storage_type=NEW.storage_type,curve_id=NEW.curve_id,a1=NEW.a1,a2=NEW.a2,a0=NEW.a0,fevap=NEW.fevap,sh=NEW.sh,hc=NEW.hc,imd=NEW.imd,y0=NEW.y0, ysur=NEW.ysur, apond=NEW.apond WHERE node_id=OLD.node_id;
       RETURN NEW;
    ELSIF TG_OP = 'DELETE' THEN
     DELETE FROM SCHEMA_NAME.node WHERE node_id=OLD.node_id;
	   DELETE FROM SCHEMA_NAME.inp_storage WHERE node_id=OLD.node_id;
	    RETURN NULL;
      END IF;
      RETURN NEW;
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;


CREATE TRIGGER "update_v_inp_edit_storage" INSTEAD OF INSERT OR UPDATE OR DELETE ON "SCHEMA_NAME"."v_inp_edit_storage"
FOR EACH ROW
EXECUTE PROCEDURE "SCHEMA_NAME"."update_v_inp_edit_storage"();




-- Function: SCHEMA_NAME.update_v_inp_edit_weir()

CREATE OR REPLACE FUNCTION SCHEMA_NAME.update_v_inp_edit_weir()
  RETURNS trigger AS
$BODY$
BEGIN
    IF TG_OP = 'INSERT' THEN
    INSERT INTO  SCHEMA_NAME.arc VALUES(NEW.arc_id,'','',NEW.z1,NEW.z2,DEFAULT,DEFAULT,'WEIR'::TEXT,NEW.sector_id,NEW.the_geom);
		INSERT INTO  SCHEMA_NAME.inp_weir VALUES(NEW.arc_id,NEW.weir_type,NEW."offset",NEW.cd,NEW.ec,NEW.cd2,NEW.flap,NEW.geom1,NEW.geom2,NEW.geom3,NEW.geom4);
		RETURN NEW;
    ELSIF TG_OP = 'UPDATE' THEN
     UPDATE SCHEMA_NAME.arc SET arc_id=NEW.arc_id,z1=NEW.z1,z2=NEW.z2,sector_id=NEW.sector_id,the_geom=NEW.the_geom WHERE arc_id=OLD.arc_id;
	   UPDATE SCHEMA_NAME.inp_weir SET arc_id=NEW.arc_id,weir_type=NEW.weir_type,"offset"=NEW."offset",cd=NEW.cd,ec=NEW.ec,cd2=NEW.cd2,flap=NEW.flap,geom1=NEW.geom1,geom2=NEW.geom2,geom3=NEW.geom3,geom4=NEW.geom4 WHERE arc_id=OLD.arc_id;
       RETURN NEW;
    ELSIF TG_OP = 'DELETE' THEN
     DELETE FROM SCHEMA_NAME.arc WHERE arc_id=OLD.arc_id;
	   DELETE FROM SCHEMA_NAME.inp_weir WHERE arc_id=OLD.arc_id;
	    RETURN NULL;
      END IF;
      RETURN NEW;
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;


CREATE TRIGGER "update_v_inp_edit_weir" INSTEAD OF INSERT OR UPDATE OR DELETE ON "SCHEMA_NAME"."v_inp_edit_weir"
FOR EACH ROW
EXECUTE PROCEDURE "SCHEMA_NAME"."update_v_inp_edit_weir"();







