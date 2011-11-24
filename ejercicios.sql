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
BEGIN
	IF (:NEW:cant_comentarios = 50) THEN
		UPDATE  G25_usuario SET categoria='senior' WHERE cod_usuario=:NEW.cod_usuario;
	ELSIF (:NEW:cant_comentarios = 11) THEN
		UPDATE G25_usuario SET categoria='intermedio' WHERE cod_usuario=:NEW.cod_usuario;
	END IF;
END;
/
---*** SOLUCION VIEJA ***---

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
/*5. Un usuario solo podr� visitar paseos donde pueda desarrollar actividades de su inter�s o bien paseos 
que no tienen ninguna actividad asociada. Si el usuario no puede realizar una visita porque no se 
desarrollan las actividades de su inter�s deber� quedar registrado en una tabla Paseo_Fallido con los 
siguientes datos: usuario, todas las actividades de inter�s del usuario en cuesti�n, nombre del paseo,
las actividades del paseo que quer�a realizar y fecha.*/


/*--TODO--TODO--TODO--TODO--TODO--TODO--TODO--TODO--TODO--TODO--TODO--TODO--TODO--TODO--TODO--TODO--TODO--TODO*/
-- Terminar agregando en tabla todas las actividades del usuario y del lugar

DROP TABLE G25_paseo_fallido ;
DROP TABLE G25_visita_fallida_tmp;

CREATE TABLE G25_paseo_fallido(
	cod_fallo		NUMERIC(10,0),
	cod_usuario		VARCHAR(20),
	cod_paseo		NUMERIC(10,0),
	cod_ciudad		NUMERIC(10,0),
	fecha			DATE
);

CREATE TABLE G25_visita_fallida_tmp(
	cod_visita		VARCHAR(20)
);


-- Nota: se decidi? poner como pk solo un codigo para simplicidad en la clave(eficiencia)	
ALTER TABLE G25_paseo_fallido
	ADD CONSTRAINT pk_paseo_fallido
		PRIMARY KEY (cod_fallo);
		
ALTER TABLE G25_paseo_fallido
	ADD CONSTRAINT fk_paseo_fallido_usuario
		FOREIGN KEY (cod_usuario) REFERENCES G25_usuario(cod_usuario);
		
ALTER TABLE G25_paseo_fallido
	ADD CONSTRAINT fk_paseo_fallido_paseo
		FOREIGN KEY (cod_paseo,cod_ciudad) REFERENCES G25_paseo(cod_paseo,cod_ciudad);
		
-- Auto incremento para paseo_fallido		
DROP SEQUENCE G25_ctr_pk_paseo_fallido ;
CREATE SEQUENCE G25_ctr_pk_paseo_fallido		
START WITH 1
INCREMENT BY 1;

CREATE OR REPLACE TRIGGER G25_confirmacion_paseo
BEFORE INSERT ON G25_visita
FOR EACH ROW
BEGIN
	DECLARE
		cuenta INTEGER;
BEGIN
	--chequear que haya actividades relacionadas al paseo
	SELECT COUNT('X') INTO cuenta FROM G25_realizada_en WHERE  cod_paseo= :NEW.cod_paseo AND cod_ciudad= :NEW.cod_ciudad; 
	IF (cuenta > 0) THEN
		--chequear que haya actividades en comun entre el usuario y el paseo
		SELECT COUNT('X') INTO cuenta
	    FROM (
		      SELECT id_actividad FROM G25_realizada_en WHERE cod_paseo= :NEW.cod_paseo AND cod_ciudad= :NEW.cod_ciudad
			  INTERSECT
			  SELECT id_actividad FROM G25_interesa_act WHERE cod_usuario= :NEW.cod_usuario
			  );
		IF (cuenta == 0) THEN
			--Paseo fallido
			/* FALTA : armar una lista concatenada de todas las actividades de inter�s del usuario en cuesti�n,
                       y otra con todas las actividades del paseo que quer�a realizar */
			
			INSERT INTO G25_paseo_fallido VALUES (ctr_pk_paseo_fallido.nextVal,:NEW.cod_usuario,:NEW.cod_paseo,:NEW.cod_ciudad,SYSDATE);
			--Evita tabla mutante
			INSERT INTO G25_visita_fallida_tmp VALUES (:NEW.cod_visita);
			--TODO PROBAR QUE GRABE
			--RAISE_APPLICATION_ERROR(-20002,'Paseo prohibido');
		END IF;
	END IF;
END;	
END;
/

CREATE OR REPLACE TRIGGER G25_confirmacion_paseo_st
AFTER INSERT ON G25_VISITA
DECLARE
	I G25_visita_fallida_tmp%ROWTYPE;
BEGIN
	FOR I IN ( SELECT * FROM G25_visita_fallida_tmp ) LOOP
		DELETE G25_VISITA WHERE cod_visita = I.cod_visita;
	END LOOP;
	DELETE FROM G25_visita_fallida_tmp;
END;
/


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
--------------------------------------------------------------------

 

SELECT *
FROM
	(SELECT * 
		FROM G25_realizada_en 
		WHERE id_actividad IN (SELECT id_actividad 
								FROM G25_actividad 
								WHERE nombre_actividad LIKE 'caminata%' ) 
				AND cod_ciudad = (SELECT cod_ciudad 
									FROM G25_ciudad 
									WHERE nombre_ciudad ='Tandil')
	)
	NATURAL JOIN (SELECT nombre_paseo,cod_paseo,cod_ciudad FROM G25_paseo)	
	NATURAL JOIN (SELECT id_actividad,nombre_actividad,elemento_necesario FROM G25_actividad )
		
	;
/* TODO Buscar foto	*/



--------------------------------------------------------------------
---------------------- Punto 8  ------------------------------------
-------------------------V 2----------------------------------------

DROP TABLE G25_COMENTARIOS_EDAD

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
		PRIMARY KEY(semana,ano,grupo,cpd_paseo);

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