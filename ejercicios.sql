--Preguntas



-- Extras

ALTER TABLE G25_usuario
MODIFY (borrado DEFAULT 'NO');


--------------------------------------------------------------------
---------------------- Punto 1  ------------------------------------
--------------------------------------------------------------------



--Restricciones de dominio a categoria
ALTER TABLE G25_usuario
ADD CONSTRAINT G25_RD_categoria
CHECK (categoria IN ('principiante','intermedio','senior'));

--Valor por default de categoria
ALTER TABLE G25_usuario
MODIFY (categoria DEFAULT 'principiante');



--Tabla con cantidad de comentarios
CREATE TABLE G25_comentarios_user(
	cod_usuario		 VARCHAR(20),
	ultimo_comentario DATE,
	cant_comentarios NUMERIC(10,0)
);

ALTER TABLE G25_comentarios_user
ADD CONSTRAINT G25_pk_comentarios_user
	PRIMARY KEY(cod_usuario);

ALTER TABLE G25_comentarios_user
ADD CONSTRAINT G25_fk_comentarios_user
	FOREIGN KEY(cod_usuario) REFERENCES G25_usuario(cod_usuario) ON DELETE CASCADE;
	
	
--Actualizacion de tabla auxiliar	
CREATE OR REPLACE TRIGGER G25_contador_comentarios	
AFTER INSERT ON G25_comentario
FOR EACH ROW
BEGIN
	DECLARE
	cont	INT;
BEGIN
	UPDATE  G25_comentarios_user SET cant_comentarios=cant_comentarios+1 WHERE cod_usuario=:NEW.cod_usuario;
END;
END;
/


--Agrega tupla en contador de comentarios cuando se da de alta en usuario
CREATE OR REPLACE TRIGGER G25_inic_contador_comentarios
AFTER INSERT ON G25_usuario
FOR EACH ROW
BEGIN
	INSERT INTO G25_comentarios_user VALUES (:NEW.cod_usuario,sysdate,0);
END;
/

-- Chequeo de cambio de categoria
CREATE OR REPLACE TRIGGER G25_cambio_categoria_user
AFTER INSERT OR UPDATE ON G25_comentarios_user
FOR EACH ROW
BEGIN
	IF (:NEW.cant_comentarios = 50) THEN
		UPDATE  G25_usuario SET categoria='senior' WHERE cod_usuario=:NEW.cod_usuario;
	ELSIF (:NEW.cant_comentarios = 11) THEN
		UPDATE G25_usuario SET categoria='intermedio' WHERE cod_usuario=:NEW.cod_usuario;
	END IF;
END;
/
/**---*** SOLUCION VIEJA ***---

-- Nota: Por problemas con tabla mutante, se generan dos triggers
----------------------------

--creaci�n de tabla temporal
-- Por eficiencia no se genera con RIR
CREATE TABLE G25_temp_comentario (
	cod_usuario			VARCHAR(20)
	);

--Trigger que genera en tabla temporal
CREATE OR REPLACE TRIGGER G25_categoria_usuario_1
BEFORE INSERT ON G25_comentario
FOR EACH ROW
BEGIN
	INSERT INTO G25_temp_comentario VALUES (:NEW.cod_usuario);
END;
/
--Trigger que chequea datos
CREATE OR REPLACE TRIGGER G25_categoria_usuario_2
AFTER INSERT ON comentario
BEGIN
	DECLARE
	cur CURSOR IS SELECT * FROM G25_temp_comentario;
	dato	G25_comentario.cod_usuario%type;
	cuenta	INTEGER;
	BEGIN
		OPEN cur;
		LOOP
			FETCH cur INTO dato;
			EXIT WHEN cur%notfound;
			SELECT COUNT('X') INTO cuenta FROM G25_comentario WHERE cod_usuario=dato;
			IF (cuenta > 50) THEN
				UPDATE  G25_usuario(categoria) SET ('avanzado') WHERE cod_usuario=dato;
			ELSIF (cuenta > 10) THEN
				UPDATE G25_usuario(categoria) SET ('intermedio') WHERE cod_usuario=dato;
			ELSE
				UPDATE G25_usuario(categoria) SET ('principiante') WHERE cod_usuario=dato;
			END IF;
		END LOOP;
		DELETE FROM aux_comentario ;
	END;
END;
/

**/







--------------------------------------------------------------------
---------------------- Punto 2  ------------------------------------
--------------------------------------------------------------------


-- Chequeo de amistad con otra persona
ALTER TABLE G25_amigo
ADD CONSTRAINT G25_check_invitacion
CHECK (cod_usuario_invitado <> cod_usuario);


--Tabla que almacena contador de amigos
CREATE TABLE G25_cant_amigos(
	cod_usuario			VARCHAR(20),
	amigos				NUMERIC(3,0)
	);

ALTER TABLE G25_cant_amigos
ADD CONSTRAINT G25_fk_cod_usuario
FOREIGN KEY (cod_usuario) REFERENCES G25_usuario(cod_usuario) ON DELETE CASCADE ;

ALTER TABLE G25_cant_amigos
ADD CONSTRAINT G25_pk_cod_usuario
PRIMARY KEY (cod_usuario) ;

	
-- Valor default para cantidad amigos
ALTER TABLE G25_cant_amigos
	MODIFY (amigos DEFAULT 0) ;
	
-- Valor maximo para amigos	de cada usuario
ALTER TABLE G25_cant_amigos
	ADD CONSTRAINT G25_cant_max_amigos
		CHECK (amigos<=500);

		
--Actualiza cantidad de amigos cuando se agrega a tabla de amigos		
CREATE OR REPLACE TRIGGER G25_agregar_amigo
AFTER INSERT ON G25_amigo
FOR EACH ROW
BEGIN
	UPDATE G25_cant_amigos SET amigos=amigos+1 WHERE cod_usuario=:NEW.cod_usuario OR cod_usuario=:NEW.cod_usuario_invitado ;
END;
/
--Actualiza cantidad de amigos cuando se elimina de tabla de amigos		
CREATE OR REPLACE TRIGGER G25_eliminar_amigo
AFTER DELETE ON G25_amigo
FOR EACH ROW
BEGIN
	UPDATE G25_cant_amigos SET amigos=amigos-1 WHERE cod_usuario=:OLD.cod_usuario OR cod_usuario=:OLD.cod_usuario_invitado ;
END;
/
	--Inicializa tabla de cantidad de amigos ante alta de usuario
	CREATE OR REPLACE TRIGGER G25_inic_cant_amigos
	AFTER INSERT ON G25_usuario
	FOR EACH ROW
	BEGIN
		INSERT INTO G25_cant_amigos(cod_usuario,amigos) VALUES (:NEW.cod_usuario,0);
	END;
	/




--------------------------------------------------------------------
---------------------- Punto 3  ------------------------------------
--------------------------------------------------------------------

ALTER TABLE G25_invitacion
	MODIFY (acepta DEFAULT 'NO');

CREATE OR REPLACE TRIGGER G25_confirmar_alta
BEFORE INSERT ON G25_usuario
FOR EACH ROW
BEGIN
	DECLARE
	aceptar G25_invitacion.acepta%type;
BEGIN
	SELECT acepta INTO aceptar 
		FROM G25_invitacion
		WHERE	email=:NEW.email;
	IF (aceptar = 'SI') THEN
		RAISE_APPLICATION_ERROR(-20005,'Email ya existente');
	ELSE
		UPDATE G25_invitacion SET acepta='SI' WHERE email=:NEW.email;
	END IF;
	EXCEPTION
	WHEN OTHERS THEN
		RAISE_APPLICATION_ERROR(-20005,'Email ya existente');
END;
END;
/




/**SOLUCION VIEJA

-- Nota: el sistema se idea para que un usuario, al registrarse, debe
-- tener su c�digo de registro, el cual ser� su pr�ximo cod_usuario. 
-- El sistema para chequear debe asegurarse que no exista el usuario
-- (ya autom�tico) y que el c�digo est� en la lista de invitaciones.
---------------------------------------------------------------------


CREATE OR REPLACE TRIGGER G25_confirmar_alta_old
BEFORE INSERT ON G25_usuario
FOR EACH ROW
BEGIN
	DECLARE
	cuenta	INTEGER;
BEGIN
	SELECT COUNT('X') INTO cuenta FROM G25_invitacion WHERE cod_usuario_invitado= :NEW.cod_usuario;
	IF (cuenta > 0) THEN
		RAISE_APPLICATION_ERROR(-20001,'Usuario no invitado');
	END IF;
END;
/
**/


--------------------------------------------------------------------
---------------------- Punto 4  ------------------------------------
--------------------------------------------------------------------


ALTER TABLE G25_tipo_actividad
ADD CONSTRAINT G25_RD_nombre
CHECK (nombre IN ('social','deportiva','cultural'));


-------------------------------------------------------------------
---------------------- Punto 5  ------------------------------------
--------------------------------------------------------------------
/*Un usuario solo podr� visitar paseos donde pueda desarrollar actividades de su inter�s o bien paseos
que no tienen ninguna actividad asociada. Si el usuario no puede realizar una visita porque no se
desarrollan las actividades de su inter�s deber� quedar registrado en una tabla Paseo_Fallido con los
siguientes datos: usuario, todas las actividades de inter�s del usuario en cuesti�n, nombre del paseo,
las actividades del paseo que quer�a realizar y fecha.*/

DROP TABLE G25_paseo_fallido ;
CREATE TABLE G25_paseo_fallido(
	cod_fallo				NUMERIC(10,0),
	cod_usuario				VARCHAR(20),
	total_actividades		VARCHAR(500),
	actividades_deseadas   	VARCHAR(500),
	fecha					DATE
);

-- Nota: se decidi? poner como pk solo un codigo para simplicidad en la clave(eficiencia)	
ALTER TABLE G25_paseo_fallido
	ADD CONSTRAINT pk_paseo_fallido
		PRIMARY KEY (cod_fallo);
		
ALTER TABLE G25_paseo_fallido
	ADD CONSTRAINT fk_paseo_fallido_usuario
		FOREIGN KEY (cod_usuario) REFERENCES G25_usuario(cod_usuario);
		
-- Auto incremento para paseo_fallido		
DROP SEQUENCE G25_ctr_pk_paseo_fallido ;
CREATE SEQUENCE G25_ctr_pk_paseo_fallido		
	START WITH 1 INCREMENT BY 1;

--TRANSACCION AUTONOMA
CREATE OR REPLACE PROCEDURE G25_insertar_visita_fallida(COD_FALLO IN INTEGER, COD_USR IN VARCHAR, COD_PAS IN INTEGER, COD_CIU IN INTEGER, D1 IN DATE) 
AS PRAGMA AUTONOMOUS_TRANSACTION ;
-- INTERTA LA VISITA FALLIDA, NO LO AFECTA EL ROLLBACK 
    Y VARCHAR(60) := '' ;
    TOTAL_ACTIVIDADES VARCHAR(500) := '';
    ACTIVIDADES_DESEADAS VARCHAR(500) := '';
    CURSOR C1 IS SELECT NOMBRE_ACTIVIDAD FROM (G25_INTERESA_ACT IACT JOIN G25_ACTIVIDAD ACT ON (IACT.ID_ACTIVIDAD = ACT.ID_ACTIVIDAD))  WHERE (COD_USUARIO = COD_USR) ;
    CURSOR C2 IS SELECT NOMBRE_ACTIVIDAD FROM (G25_REALIZADA_EN RACT JOIN G25_ACTIVIDAD ACT ON (RACT.ID_ACTIVIDAD = ACT.ID_ACTIVIDAD))  WHERE ((COD_PASEO = COD_PAS) AND (COD_CIUDAD = COD_CIU)) ;
BEGIN
	OPEN C1; 
	FETCH C1 INTO Y ;
	WHILE C1%FOUND LOOP 
		TOTAL_ACTIVIDADES := CONCAT (CONCAT( TOTAL_ACTIVIDADES, '; '), Y) ;
		FETCH C1 INTO Y ;
	END LOOP;
	Y := '';
	OPEN C2; 
	FETCH C2 INTO Y ;
	WHILE C2%FOUND LOOP 
		ACTIVIDADES_DESEADAS := CONCAT (CONCAT( ACTIVIDADES_DESEADAS, '; '), Y) ;
		FETCH C2 INTO Y ;
	END LOOP;
    INSERT INTO G25_PASEO_FALLIDO VALUES ( COD_FALLO, COD_USR, TOTAL_ACTIVIDADES, ACTIVIDADES_DESEADAS, D1 ) ;
    COMMIT ;
END;
/
SHOW ERRORS PROCEDURE g25_insertar_visita_fallida ;


CREATE OR REPLACE TRIGGER G25_confirmacion_paseo
AFTER INSERT ON G25_visita
FOR EACH ROW
DECLARE
	cuenta INTEGER;
BEGIN
	--chequear que haya actividades relacionadas al paseo
	SELECT COUNT('X') INTO cuenta FROM G25_realizada_en WHERE  ( cod_paseo = :NEW.cod_paseo) AND cod_ciudad= :NEW.cod_ciudad; 
	IF (cuenta > 0) THEN
		--chequear que haya actividades en comun entre el usuario y el paseo
		SELECT COUNT('X') INTO cuenta
	    FROM (
		    SELECT id_actividad FROM G25_realizada_en WHERE ( cod_paseo = :NEW.cod_paseo) AND ( cod_ciudad = :NEW.cod_ciudad )
			INTERSECT
			SELECT id_actividad FROM G25_interesa_act WHERE (cod_usuario = :NEW.cod_usuario)
			);
		IF (cuenta = 0) THEN
			--Paseo fallido
			G25_insertar_visita_fallida(G25_ctr_pk_paseo_fallido.nextVal,:NEW.cod_usuario,:NEW.cod_paseo,:NEW.cod_ciudad,SYSDATE);
			RAISE_APPLICATION_ERROR(-20002,'Paseo prohibido');
		END IF;
	END IF;	
END;
/
SHOW ERRORS TRIGGER G25_CONFIRMACION_PASEO ;


--------------------------------------------------------------------
---------------------- Punto 6  ------------------------------------
--------------------------------------------------------------------
-- Nota: Se supondr� que el orden de insercion en la tabla es: 
-- Comentario -> Original o respuesta -> en_muro o visita
-- Por lo que se hace un trigger para cada tabla chequeando que el dato
-- se encuentre en su tabla superior
---------------------------------------------------------------------


CREATE OR REPLACE TRIGGER G25_corresp_original
AFTER INSERT ON G25_original
FOR EACH ROW
BEGIN
	DECLARE
	cuenta INT;
BEGIN
	SELECT COUNT('X') INTO cuenta FROM G25_comentario C WHERE (C.cod_comentario = :NEW.cod_comentario) AND (C.tipo = 'Original') ;
	IF (cuenta=0) THEN
		RAISE_APPLICATION_ERROR(-20003,'Error de jerarquia original');
	END IF;
END;
END;
/


CREATE OR REPLACE TRIGGER G25_corresp_respuesta
AFTER INSERT ON G25_respuesta
FOR EACH ROW
BEGIN
	DECLARE
	cuenta INT;
BEGIN
	SELECT COUNT('X') INTO cuenta FROM G25_comentario C WHERE (C.cod_comentario = :NEW.cod_comentario) AND (C.tipo = 'Respuesta') ;
	IF (cuenta=0) THEN
		RAISE_APPLICATION_ERROR(-20004,'Error de jerarquia respuesta');
	END IF;
END;
END;
/



CREATE OR REPLACE TRIGGER G25_corresp_en_muro
AFTER INSERT ON G25_en_muro
FOR EACH ROW
BEGIN
	DECLARE
	cuenta INT;
BEGIN
	SELECT COUNT('X') INTO cuenta FROM G25_original O WHERE (O.cod_comentario = :NEW.cod_comentario) AND (O.tipodeorig = 'En muro') ;
	IF (cuenta=0) THEN
		RAISE_APPLICATION_ERROR(-20005,'Error de jerarquia en muro');
	END IF;
END;
END;
/



CREATE OR REPLACE TRIGGER G25_corresp_en_visita
AFTER INSERT ON G25_en_visita
FOR EACH ROW
BEGIN
	DECLARE
	cuenta INT;
BEGIN
	SELECT COUNT('X') INTO cuenta FROM G25_original O WHERE (O.cod_comentario = :NEW.cod_comentario) AND (O.tipodeorig = 'En visita') ;
	IF (cuenta=0) THEN
		RAISE_APPLICATION_ERROR(-20006,'Error de jerarquia en visita');
	END IF;
END;
END;
/


--------------------------------------------------------------------
---------------------- Punto 7  ------------------------------------
-------------------------V 2----------------------------------------


/*
7. Los paseos de Tandil en los que pueden realizarse �caminatas� son muy visitados, por lo que siempre
son motivo de consulta. Los potenciales visitantes desean saber :
1) que otras actividades se realizan en esos paseos,
2) si es necesario llevar alg�n elemento para desarrollar la/s actividades durante la visita. 
3) Tambi�n desean ver alguna imagen de cada lugar.
*/

create or replace function g25_obtener_imagenes( cod_p in varchar, cod_c in varchar ) return varchar is
-- OBTIENE TODAS LAS IMAGENES (p�blicas) ASOCIADAS A UN PASEO , Y LAS CONCATENA EN UN VARCHAR.
	cursor c1 is select foto.imagen from (
                                          (select cod_visita from g25_visita visita where visita.cod_paseo = cod_p and visita.cod_ciudad = cod_c ) aux
                                          join g25_informacion informacion on ( aux.cod_visita = informacion.cod_visita and informacion.privacidad = 'publico')
                                          join g25_foto foto on ( foto.cod_informacion = informacion.cod_informacion) 
                                          ) ;
                                                           
    y varchar(30) := '' ;
    imagenes varchar(500) := '' ;
begin	
    OPEN C1; 
    FETCH C1 INTO Y ;
    WHILE C1%FOUND LOOP 
      	imagenes := CONCAT ( y, CONCAT(', ',imagenes )) ;
        FETCH C1 INTO Y ;
  	END LOOP;
    return imagenes ;
end ;
/

create or replace function g25_obtener_actividades( cod_p in varchar, cod_c in varchar ) return varchar is
-- OBTIENE TODAS LAS ACTIVIDADES ASOCIADAS A UN PASEO , Y LAS CONCATENA EN UN VARCHAR.
	cursor c1 is select actividad.nombre_actividad from (
                                          (select id_actividad from g25_realizada_en where cod_paseo = cod_p and cod_ciudad = cod_c ) aux
                                          join g25_actividad actividad on ( actividad.id_actividad = aux.id_actividad) 
                                          ) ;
                                                           
    y varchar(30) := '' ;
    actividades varchar(500) := '' ;
begin	
    OPEN C1; 
    FETCH C1 INTO Y ;
    WHILE C1%FOUND LOOP 
      	actividades := CONCAT ( y, CONCAT(', ',actividades )) ;
       FETCH C1 INTO Y ;
  	END LOOP;
    return actividades ;
end ;
/

show errors function g25_obtener_actividades ;

create or replace function g25_obtener_elementos( cod_p in varchar, cod_c in varchar ) return varchar is
-- OBTIENE TODAS LAS ACTIVIDADES ASOCIADAS A UN PASEO , Y LAS CONCATENA EN UN VARCHAR.
	cursor c1 is select actividad.elemento_necesario from (
                                          (select id_actividad from g25_realizada_en where cod_paseo = cod_p and cod_ciudad = cod_c ) aux
                                          join g25_actividad actividad on ( actividad.id_actividad = aux.id_actividad) 
                                          ) ;
                                                           
    y varchar(30) := '' ;
    elementos varchar(500) := '' ;
begin	
    OPEN C1; 
    FETCH C1 INTO Y ;
    WHILE C1%FOUND LOOP 
      	elementos := CONCAT ( y, CONCAT(', ',elementos )) ;
       FETCH C1 INTO Y ;
  	END LOOP;
    return elementos ;
end ;
/

show errors function g25_obtener_elementos ;

create or replace view g25_caminatas_tandilenses as 
SELECT P.*, 
       G25_OBTENER_IMAGENES(P.COD_PASEO, P.COD_CIUDAD) AS IMAGENES,
       G25_OBTENER_ACTIVIDADES(P.COD_PASEO, P.COD_CIUDAD) AS ACTIVIDADES,
       g25_obtener_elementos(P.cod_paseo, P.cod_ciudad) as elementos
FROM 
      (SELECT P1.*
            FROM G25_PASEO P1 
            WHERE (P1.COD_PASEO IN ( SELECT R.COD_PASEO 
                                    FROM G25_REALIZADA_EN R JOIN G25_ACTIVIDAD AC ON (R.id_actividad = AC.id_actividad)
                                    WHERE (AC.NOMBRE_ACTIVIDAD LIKE 'caminata%')
                                  )
        )     ) P
        JOIN G25_CIUDAD CIU ON ( p.cod_ciudad = ciu.cod_ciudad AND ciu.nombre_ciudad = 'Tandil') 
;


--------------------------------------------------------------------
---------------------- Punto 8  ------------------------------------
-------------------------V 2----------------------------------------

DROP TABLE G25_COMENTARIOS_EDAD;

--funcion que extrae semana del ano de una fecha
CREATE OR REPLACE FUNCTION G25_date_to_week(fecha IN DATE) RETURN INTEGER IS
	week INTEGER;
BEGIN
	select trunc(to_number(to_char(fecha,'ww'))) INTO week from dual;
	RETURN week;
END;
/

--Tabla que almacena cant_comentarios organizado por semana, grupo de edad y paseo
CREATE TABLE G25_comentarios_edad(
	semana 				NUMERIC(3),
	ano 				NUMERIC(4),
	grupo				VARCHAR(7),
	cod_paseo			NUMERIC(10),
	cod_ciudad			NUMERIC(10),
	cant_comentarios	NUMERIC(7)
	);

--Default cantidad de comentarios
ALTER TABLE G25_comentarios_edad
	MODIFY (cant_comentarios DEFAULT 0) ;

--RD grupos
ALTER TABLE G25_comentarios_edad
	ADD CONSTRAINT G25_RD_grupo
		CHECK (grupo IN ('ninos','jovenes','adultos'));

--PK		
ALTER TABLE G25_comentarios_edad
	ADD CONSTRAINT G25_pk_comentarios_edad
		PRIMARY KEY(semana,ano,grupo,cod_paseo);

--FK
ALTER TABLE G25_comentarios_edad
	ADD CONSTRAINT G25_fk_comentarios_edad_paseo
		FOREIGN KEY(cod_paseo,cod_ciudad) REFERENCES G25_paseo;



--Trigger controlador de actualizado de tabla de contadores de comentarios en paseo
CREATE OR REPLACE TRIGGER G25_contador_com_edad
AFTER INSERT ON G25_en_visita
FOR EACH ROW
BEGIN
	DECLARE
	edad	INTEGER;
	control	INTEGER;
	comentario	G25_comentario%ROWTYPE;
	visita		G25_visita%ROWTYPE;
	var_grupo		VARCHAR(7);
BEGIN
	--obtener comentario completo
	SELECT * INTO comentario FROM G25_comentario WHERE cod_comentario=:NEW.cod_comentario;
	
	--obtener edad de usuario
	SELECT trunc((to_number(to_char(sysdate,'yyyymmdd'))
			-to_number(to_char(fecha_nacimiento,'yyyymmdd'))
			)/10000)
	INTO edad FROM G25_usuario WHERE cod_usuario=comentario.cod_usuario;
	
	--obtener paseo
	SELECT * INTO visita FROM G25_visita WHERE cod_visita=:NEW.cod_visita;
	
	--Setear grupo
	IF (edad > 21) THEN
		var_grupo:='adultos';
	ELSIF (edad>14) THEN
		var_grupo:='jovenes';
	ELSE
		var_grupo:='ninos';
	END IF;
	
	
	--Inicializar valores si es nueva semana o nuevo paseo
	SELECT COUNT('X') INTO control FROM G25_comentarios_edad WHERE ano=trunc(to_number(to_char(sysdate,'yyyy'))) AND semana=G25_date_to_week(sysdate)
																 AND grupo=var_grupo AND cod_paseo=visita.cod_paseo AND cod_ciudad=visita.cod_ciudad;
	IF (control = 0) THEN --inicializacion
		INSERT INTO G25_comentarios_edad(semana,ano,grupo,cod_paseo,cod_ciudad) 
				VALUES (G25_date_to_week(sysdate),trunc(to_number(to_char(sysdate,'yyyy'))),var_grupo,visita.cod_paseo,visita.cod_ciudad);
	END IF;
	
	--Agregar al contador
		UPDATE G25_comentarios_edad SET cant_comentarios=cant_comentarios+1 WHERE ano=trunc(to_number(to_char(sysdate,'yyyy'))) AND semana=G25_date_to_week(sysdate)
																 AND grupo=var_grupo AND cod_paseo=visita.cod_paseo AND cod_ciudad=visita.cod_ciudad;
END;
END;
/

		
		




--------------------------------------------------------------------
---------------------- Punto 9  ------------------------------------
--------------------------------------------------------------------

-- Tabla que almacena toda la informacion necesaria
CREATE TABLE G25_log_paseo(
	id_log		NUMERIC(10),
	cod_paseo	NUMERIC(10),
	cod_ciudad	NUMERIC(10),
	fecha		DATE,
	accion		VARCHAR(10),
	nombre_paseo	VARCHAR(150),
	descripcion	VARCHAR(255),
	cod_usuario	VARCHAR(20)
);

--secuencia para pk de logeo
CREATE SEQUENCE G25_pk_log_paseo		
START WITH 1
INCREMENT BY 1;


-- pk log_paseo
ALTER TABLE G25_log_paseo
	ADD CONSTRAINT G25_pk_log_paseo
		PRIMARY KEY(id_log);

-- Restriccion de dominio para la accion
ALTER TABLE G25_log_paseo
	ADD CONSTRAINT G25_RD_accion
		CHECK(accion IN ('DELETE','INSERT','UPDATE'));



CREATE OR REPLACE TRIGGER G25_logging_paseo
AFTER INSERT OR DELETE OR UPDATE ON G25_paseo
FOR EACH ROW
BEGIN
	IF INSERTING THEN
		INSERT INTO G25_log_paseo(id_log,cod_paseo,cod_ciudad,fecha,accion,nombre_paseo,descripcion,cod_usuario) 
			VALUES (G25_pk_log_paseo.nextVal,:NEW.cod_paseo,:NEW.cod_ciudad,sysdate,'INSERT',:NEW.nombre_paseo,:NEW.descripcion,:NEW.cod_usuario);
	ELSIF DELETING THEN		
		INSERT INTO G25_log_paseo(id_log,cod_paseo,cod_ciudad,fecha,accion,nombre_paseo,descripcion,cod_usuario) 
			VALUES (G25_pk_log_paseo.nextVal,:OLD.cod_paseo,:OLD.cod_ciudad,sysdate,'DELETE',:OLD.nombre_paseo,:OLD.descripcion,:OLD.cod_usuario);
	ELSIF UPDATING THEN
		INSERT INTO G25_log_paseo(id_log,cod_paseo,cod_ciudad,fecha,accion,nombre_paseo,descripcion,cod_usuario) 
			VALUES (G25_pk_log_paseo.nextVal,:NEW.cod_paseo,:NEW.cod_ciudad,sysdate,'UPDATE',:OLD.nombre_paseo,:OLD.descripcion,:OLD.cod_usuario);
	END IF;
END;
/

--------------------------------------------------------------------
---------------------- Punto 10  ------------------------------------
--------------------------------------------------------------------


CREATE OR REPLACE PROCEDURE G25_paseo_recovery (fecha_max DATE) AS
	CURSOR cur IS SELECT * FROM G25_log_paseo WHERE fecha > fecha_max ORDER BY id_log DESC;
	accion	G25_log_paseo%ROWTYPE;
BEGIN
	OPEN cur ;
	IF (cur%isopen) THEN
		LOOP
			FETCH cur INTO accion;
			EXIT WHEN cur%notfound;
			IF ( accion.accion = 'INSERT'	)	THEN
				DELETE FROM G25_paseo WHERE cod_paseo=accion.cod_paseo AND cod_ciudad=accion.cod_ciudad;
			ELSIF ( accion.accion = 'DELETE') THEN
				INSERT INTO G25_paseo(cod_ciudad,cod_paseo,nombre_paseo,descripcion,cod_usuario) 
							VALUES (accion.cod_ciudad,accion.cod_paseo,accion.nombre_paseo,accion.descripcion,accion.cod_usuario);
			ELSE 
				UPDATE G25_paseo SET nombre_paseo=accion.nombre_paseo , descripcion=accion.descripcion , cod_usuario=accion.cod_usuario
							WHERE (cod_paseo=accion.cod_paseo AND cod_ciudad=accion.cod_ciudad);
			END IF;
		END LOOP;
	END IF;
END;
/





--------------------------------------------------------------------
---------------------- Punto 11  -----------------------------------
--------------------------------------------------------------------


/*
11. Con fines estad�sticos, a fin del d�a se elaborar� un informe con los siguientes datos: 
1) todos los datos del paseo m�s visitado, 
2) todos los datos del usuario que m�s comentarios haya realizado, 
3) el/los usuarios que m�s informaci�n haya/n subido (aclarando la cantidad de cada tipo, 
el que m�s haya subido tendr� la mayor suma de cantidades), 
4) Y las 5 actividades m�s desarrolladas en los paseos por los usuarios que hicieron visitas en ese d�a. 
*/

create or replace view g25_paseo_mas_visitado as
select paseo.* from ( select V.cod_paseo, v.cod_ciudad , count( concat(concat(v.cod_paseo, ';'), v.cod_ciudad)) as total from g25_visita  V
                where (to_char(v.fecha, 'dd/mm/yyyy') = to_char(sysdate, 'dd/mm/yyyy'  ))
                group by (V.cod_paseo, V.cod_ciudad)
                ORDER BY count( concat(concat(v.cod_paseo, ';'), v.cod_ciudad)) DESC 
              ) t1 join g25_paseo paseo on (t1.cod_paseo = paseo.cod_paseo and paseo.cod_ciudad = t1.cod_ciudad)
where rownum <= 1
;

select * from g25_paseo_mas_visitado ;


/* el usuarios que m�s comento */
/* falta agregar al modelo fecha comentario*/
alter table g25_comentario
	add fecha date ;

create or replace view g25_usuario_mas_comento as
select usr.*, total_comentarios from ( select com.cod_usuario usr, count(com.cod_usuario) as total_comentarios from g25_comentario com
                where (to_char(com.fecha, 'dd/mm/yyyy') = to_char(sysdate, 'dd/mm/yyyy'  ))
                group by (com.cod_usuario)
                ORDER BY count( com.cod_usuario ) DESC 
              ) join g25_usuario usr on ( usr.cod_usuario = usr ) 
where rownum <= 1
;

select * from g25_usuario_mas_comento ;


/* el/los usuarios que m�s informaci�n haya/n subido (aclarando la cantidad de cada tipo, 
el que m�s haya subido tendr� la mayor suma de cantidades), */

--se agrego el campo fecha a la informacion INDISPENSABLE
alter table g25_informacion
	add fecha date ;

create or replace view g25_usuario_mas_info as
select cod_usuario, tipo_info, count(informacion.cod_informacion) as cantidad 
from g25_visita visita join g25_informacion informacion on (informacion.cod_visita = visita.cod_visita)
group by (cod_usuario, tipo_info)
having cod_usuario = ( select cod_usuario 
                       from ( select v.cod_usuario, count(cod_informacion) as cant
                              from g25_visita v join g25_informacion i on (i.cod_visita = v.cod_visita)
                              where to_char(v.fecha,'dd/mm/yyyy') = to_char(sysdate,'dd/mm/yyyy')
                              group by v.cod_usuario
                              order by cant desc
                             ) tabla_aux
                      where rownum =1
                      );
                      
select * from g25_usuario_mas_info ;
/*4) Y las 5 actividades m�s desarrolladas en los paseos por los usuarios que hicieron visitas en ese d�a. 
*/

-- se supone que un usuario desarrolla todas las actividades del paseo visitado
create or replace view g25_mas_desarolladas as
select * from (
                select realizada.id_actividad, count( realizada.id_actividad ) as total 
                from g25_visita visita join g25_paseo paseo on ((visita.cod_paseo = paseo.cod_paseo) and (visita.cod_ciudad = paseo.cod_ciudad) ) and (to_char(visita.fecha, 'dd/mm/yyyy') = to_char(sysdate, 'dd/mm/yyyy') ) 
                                       join g25_realizada_en realizada on (realizada.cod_paseo = paseo.cod_paseo and realizada.cod_ciudad = paseo.cod_ciudad)
                group by (realizada.id_actividad)
                ORDER BY count( realizada.id_actividad) DESC 
              )
where rownum <= 5
;
select * from g25_mas_desarolladas ;




--------------------------------------------------------------------
---------------------- Punto 12  -----------------------------------
--------------------------------------------------------------------
/*
12. En un archivo de texto se guardar� la actividad de cada uno de los usuarios (el nombre del archivo
ser� USU_cod_usuario) con el objetivo de tener un backup fuera de la base.
*/
-- IMPORTANTE: hago backup de todas las visitas realizadas por los usuarios

connect sys/954120 as sysdba ;
grant execute on utl_file to public;

create or replace directory g25_temp as 'c:\temp' ;
grant read, write on directory g25_temp to public ;

create or replace procedure g25_guardar_visita( cod_usr in varchar )
AS PRAGMA AUTONOMOUS_TRANSACTION ;
    f utl_file.file_type;
    encabezado varchar(50) := 'cod_visita | cod_ciudad | cod_paseo | fecha' ;
    cursor c1 is select concat(concat(concat(concat(concat(concat(cod_visita, ' | '), cod_ciudad),' | '),cod_paseo),' | '),to_char(fecha, 'dd/mm/yyyy')) from system.g25_visita where cod_usuario = cod_usr;
    y varchar(50) := '' ;
begin
    y := concat(concat('USU_', cod_usr), '.txt');
    f := utl_file.fopen('G25_TEMP',y,'w');
    utl_file.put_line(f, encabezado) ;
    utl_file.put_line(f, '--------------------------------------------') ;
    OPEN C1; 
  	FETCH C1 INTO Y ;
    WHILE C1%FOUND LOOP 
        utl_file.put_line(f, y) ;   	
        FETCH C1 INTO Y ;
    END LOOP;
    utl_file.fclose(f);

end ;
/ 
--show errors procedure g25_guardar_visita ;

create or replace procedure g25_backup_visitas 
AS PRAGMA AUTONOMOUS_TRANSACTION ;
    cursor c1 is select distinct cod_usuario from system.g25_visita;
    y varchar(50) := '' ;
begin
    OPEN C1; 
  	FETCH C1 INTO Y ;
    WHILE C1%FOUND LOOP 
        g25_guardar_visita(y) ;
        FETCH C1 INTO Y ;
    END LOOP;
end ;
/ 
--show errors procedure g25_backup_visitas ;

--execute g25_backup_visitas ;