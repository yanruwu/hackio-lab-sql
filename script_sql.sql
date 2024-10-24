--Ejercicio 1. Queries Generales
	--1.1. Calcula el promedio más bajo y más alto de temperatura.
with promedios as (select avg(t.temperatura) as promedio_temperatura 
					from tiempo t 
					group by t.id_municipio)
select min(promedio_temperatura), max(promedio_temperatura) 
from promedios;

	--1.2. Obtén los municipios en los cuales coincidan las medias de la sensación térmica y de la temperatura.
with promedios2 as (select avg(t.temperatura) as promedio_temperatura2,
					avg(t.sens_térmica) as promedio_sens_termica,
					t.id_municipio as m_id
					from tiempo t 
					group by t.id_municipio)
select m_id, promedio_temperatura2, promedio_sens_termica
from promedios2
where promedio_temperatura2 = promedio_sens_termica;


	--1.3. Obtén el local más cercano de cada municipio
with distancias_min as (select min(l.distancia) as min_d
						from lugares l group by l.id_municipio)
select l.nombre, l.id_municipio, dm.min_d from distancias_min dm
inner join lugares l on l.distancia = dm.min_d;

	--1.4. Localiza los municipios que posean algún localizador a una 
	--		distancia mayor de 2000 y que posean al menos 25 locales.
with criterios as (select l.id_municipio as m_id,
					count(l.id_lugar) as n_lugares,
					max(l.distancia) as max_d
					from lugares l group by l.id_municipio)
select * from criterios
where n_lugares > 25 
and max_d > 2000

	--1.5. Teniendo en cuenta que el viento se considera leve con una velocidad media de entre 6 y 20 km/h,
	-- moderado con una media de entre 21 y 40 km/h, fuerte con media de entre 41 y 70 km/h y muy fuerte entre
	-- 71 y 120 km/h. Calcula cuántas rachas de cada tipo tenemos en cada uno de los días.
with clasificacion_viento as (select t.vel_viento, id_municipio, 
	case 
		when (t.vel_viento >= 6) and (t.vel_viento <= 20) then 'leve'
		when (t.vel_viento >= 21) and (t.vel_viento <= 40) then 'moderado'
		when (t.vel_viento >= 41) and (t.vel_viento <= 70) then 'alto'
		else 'fuera de rango'
	end as rango_viento
	from tiempo t )
select  id_municipio, count(rango_viento), rango_viento from clasificacion_viento
group by id_municipio, rango_viento
order by id_municipio


--Ejercicio 2. Vistas
	--2.1. Crea una vista que muestre la información de los locales que tengan incluido 
	--el código postal en su dirección.

create view locales_con_postal as
select * from lugares l
where l.direccion ~ '\d{5}';

	--2.2. Crea una vista con los locales que tienen más de una categoría asociada.
create view locales_varias_categorias as
select * , count(distinct (categoria))
from lugares l 
group by l.id_lugar 
having count(distinct (categoria))>1; -- En este caso no tenemos lugares con la misma id
									  --pero distinta categoría. Esto puede ser porque al crear
									  -- la BBDD quitamos duplicados.
	--2.3. Crea una vista que muestre el municipio con la temperatura más alta de cada día
create view temperaturas_maximas_cada_dia as
with max_temp_dia as (
select fecha , max(t.temperatura) as temp_max
from tiempo t 
group by fecha)
select t.fecha, t.id_municipio, t.temperatura from tiempo t
inner join max_temp_dia m
on t.fecha = m.fecha and t.temperatura = m.temp_max
order by fecha asc;

	--2.4. Crea una vista con los municipios en los que haya una probabilidad de 
	--precipitación mayor del 100% durante mínimo 7 horas.

create view municipios_prob_lluvia_alta as
select t.id_municipio, fecha from tiempo t 
where prob_precip = 'Muy alta'
group by id_municipio, fecha
having count(distinct id_daystage) >= 3;
	-- Ya que en mi BBDD no hay horas sino daystages (4 en cada día) y la prob de lluvia es categórica
	-- he modificado el enunciado a prob_prec = Muy alta durante al menos 3 fases del día.

	--2.5. Obtén una lista con los parques de los municipios que tengan algún castillo.
create view parques_municipio_con_castillo as
select l.nombre, l.id_municipio from lugares l
where l.categoria = 'Park'
and l.id_municipio in (select l2.id_municipio from lugares l2
						where l2.categoria ~* 'castle');
						
--Ejercicio 3. Tablas Temporales
	--3.1. Crea una tabla temporal que muestre cuántos días han pasado desde que se obtuvo 
	--la información de la tabla AEMET.
create temporary table dias_pasados as
select id_municipio, fecha,
current_date - fecha as dias_transcurridos
from tiempo t ;

	--3.2. Crea una tabla temporal que muestre los locales que tienen más de una categoría 
	--asociada e indica el conteo de las mismas
--create temporary table locales_mas_categoria as
select id_lugar, nombre, count(distinct categoria) from lugares l 
group by id_lugar
having count(distinct categoria)>1;
	-- por construcción de BBDD, no hay ninguno

alter table tiempo 

	--3.3. Crea una tabla temporal que muestre los tipos de cielo para los cuales la probabilidad 
	--de precipitación mínima de los promedios de cada día es 5.

	-- he modificado para que en vez de promedio sea moda = 'Baja'

CREATE TEMPORARY TABLE tipos_cielo_precip_minima AS
select distinct t.fecha, t.cielo, t.prob_precip
from tiempo t
where t.prob_precip = 'Baja'
order by fecha 

	--3.4. Crea una tabla temporal que muestre el tipo de cielo más y menos repetido por municipio.
create temporary table cielos_mas_menos_repetidos as
with conteo_cielos as (
	select cielo, count(id_tiempo) as conteo, id_municipio
	from tiempo
	group by cielo, id_municipio
),
max_conteos as (
	select id_municipio, cielo, conteo
	from conteo_cielos
	where (id_municipio, conteo) in (select id_municipio, max(conteo) 
					from conteo_cielos 
					group by id_municipio)
),
min_conteos as (
	select id_municipio, cielo, conteo
	from conteo_cielos
	where (id_municipio, conteo) in (select id_municipio, min(conteo) 
					from conteo_cielos 
					group by id_municipio)
)
select mac.id_municipio, mac.cielo as cielo_mas, 
		mac.conteo as conteo_mas , mic.cielo as cielo_menos, 
		mic.conteo as conteo_menos
from max_conteos mac
join min_conteos mic on mac.id_municipio = mic.id_municipio
order by id_municipio;

--Ejercicio 4. SUBQUERIES
	--4.1. Necesitamos comprobar si hay algún municipio en el cual no tenga ningún 
	--local registrado.
select id_municipio from municipios m 
where m.id_municipio not in (select l.id_municipio from lugares l);

	--4.2. Averigua si hay alguna fecha en la que el cielo se encuente 
	--"Muy nuboso con tormenta".
select distinct fecha from tiempo
where fecha in (select fecha from tiempo where cielo ~ 'Muy nuboso con tormenta')

	--4.3. Encuentra los días en los que los avisos sean diferentes a "Sin riesgo".
select distinct fecha
from tiempo t 
where fecha in (select fecha
				from tiempo t2
				where avisos != 'Sin riesgo');
				
	--4.4. Selecciona el municipio con mayor número de locales.
select id_municipio 
from lugares l
group by id_municipio 
having count(id_lugar) = (select max(conteo) 
							from (select count(id_lugar) as conteo
									from lugares l2 
									group by id_municipio 
								) as conteos);
								
	--4.5. Obtén los municipios muya media de sensación térmica sea mayor que la media total.
select id_municipio
from tiempo t 
group by id_municipio 
having avg(t.sens_térmica) > (select avg(t2.sens_térmica)
						from tiempo t2);
						
	--4.6. Selecciona los municipios con más de dos fuentes.
select distinct id_municipio 
from lugares
where id_municipio in (select id_municipio
						from lugares l 
						where categoria = 'Fountain'
						group by id_municipio 
						having count(id_lugar)>2);
						
	--4.7. Localiza la dirección de todos los estudios de cine 
	--que estén abiertos en el municipio de "Madrid".
select direccion 
from lugares l 
where closed_bucket = 'LikelyOpen' 
and id_municipio = 'madrid' 
and categoria = 'Film Studio';

	--4.8. Encuentra la máxima temperatura para cada tipo de cielo.
select distinct cielo, max(temperatura) as temp_max
from tiempo
group by cielo


	--4.9. Muestra el número de locales por categoría que muy probablemente 
	--se encuentren abiertos.
select categoria, count(id_lugar) as n_locales
from lugares l 
where id_lugar in (select id_lugar
					from lugares l2
					where closed_bucket = 'VeryLikelyOpen')
group by categoria;

