DROP TABLESPACE sql3tbs
INCLUDING CONTENTS AND DATAFILES
CASCADE CONSTRAINTS;

DROP TABLESPACE sql3temptbs
INCLUDING CONTENTS AND DATAFILES
CASCADE CONSTRAINTS;

DROP USER sql3 CASCADE;
--2. Créer deux TableSpaces SQL3_TBS et SQL3_TempTBS
CREATE TableSpace SQL3TBS DATAFILE 'C:\SQL3TBS.dat'  SIZE 100M  AUTOEXTEND ON   ONLINE;
CREATE TEMPORARY TABLESPACE SQL3TempTBS  TEMPFILE 'C:\SQL3TempTBS.dat' SIZE 100M  AUTOEXTEND ON;



-- 3. Créer un utilisateur SQL3 en lui attribuant les deux tablespaces créés précédemment 
Create user SQL3 identified by psw Default Tablespace SQL3TBS Temporary Tablespace  SQL3TempTBS ;
 --4. Donner tous les privilèges à cet utilisateur.
GRANT ALL PRIVILEGES TO SQL3;
 connect SQL3/psw;
 show user;
 --5. En se basant sur le diagramme de classes fait, définir tous les types nécessaires.
 -- Prendre en compte toutes les associations qui existent. 
Create type thotel;
/
Create type tchambre;
/
Create type tclient;
/
Create type treservation;
/
Create type tevaluation;
/


-- les types de ref :

create or replace type t_set_ref_chambre as table of ref tchambre;
/
create or replace type t_set_ref_evaluation as table of ref tevaluation;
/
create or replace type t_set_ref_reservation as table of ref treservation;
/

--- Mise à jour de type incomplet:
Create or replace type thotel as object (
    NUMHOTEL INTEGER, 
    NOMHOTEL VARCHAR2(50), 
    VILLE VARCHAR2(50), 
    ETOILES INTEGER,
    SiteWeb VARCHAR2(50),
    hotel_chambre t_set_ref_chambre,
    hotel_evaluation t_set_ref_evaluation
   );
    /
Create or replace type tchambre as object(
    NUMCHAMBRE INTEGER, 
    NUMHOTEL INTEGER,
    ETAGE INTEGER, 
    TYPECHAMBRE VARCHAR2(30),
    PRIXNUIT INTEGER,
    chambre_hotel ref thotel,
    chambre_res t_set_ref_reservation);
    /
Create or replace type tclient as object(
    NUMCLIENT INTEGER, 
    NOMCLIENT VARCHAR2(50), 
    PRENOMCLIENT VARCHAR2(50), 
    Email VARCHAR2(50),
    client_res t_set_ref_reservation,
    client_eval t_set_ref_evaluation);
    /


Create or replace type treservation as object(
    NUMRES INTEGER,
    DATEARRIVEE DATE, 
    DATEDEPART DATE, 
    
    res_client ref tclient,
    res_chambre ref tchambre
    );
    /
Create or replace type tevaluation as object(
   NUMEVAL INTEGER,
   datee DATE, 
   Note INTEGER,
   eval_client ref tclient,
   eval_hotel ref thotel
);
    /

-- 6. Définir les méthodes permettant de :
-- - Calculer pour chaque client, le nombre de réservations effectuées.
alter type tclient add member function nbr_res_client return INTEGER CASCADE;

Create or replace type body tclient as member function nbr_res_client return INTEGER is
nb INTEGER;
BEGIN
select count(distinct t.column_value) INTO nb from table(self.client_res) t;
return nb;
END nbr_res_client;
END;
/
-- Calculer pour chaque hôtel, le nombre de chambres.
--- Calculer pour chaque hôtel, le nombre d’évaluations reçues à une date donnée (01-01-2022
alter type thotel add member function nbr_chambre return INTEGER CASCADE;
alter type thotel add member function nombre_eval(d DATE) return INTEGER CASCADE;


Create or replace type body thotel as member function nbr_chambre return INTEGER is
nb INTEGER;
BEGIN
select count(distinct t.column_value) INTO nb from table(self.hotel_chambre) t;
return nb;
END nbr_chambre;
member function nombre_eval(d DATE) return INTEGER is
nbeval INTEGER;
BEGIN
SELECT count(distinct t.column_value) INTO nbeval 
FROM table(self.hotel_evaluation) t where deref(t.column_value).datee=d ;
return nbeval;
END nombre_eval;
END;
/

--- Calculer pour chaque chambre, son chiffre d’affaire.
alter type tchambre add member function calcul_chiffre return INTEGER CASCADE;

CREATE OR REPLACE TYPE BODY tchambre AS MEMBER FUNCTION calcul_chiffre RETURN INTEGER IS
    ch_aff INTEGER;
  BEGIN
    SELECT count(t.column_value) INTO ch_aff FROM table(self.chambre_res) t;
    

    RETURN ch_aff*self.PRIXNUIT;
  END calcul_chiffre;
END;
/




select h.numhotel,h.nbr_chambre() from hotel h where h.numhotel=1;

-- Définition des tables nécessaires :

CREATE TABLE Hotel OF thotel(PRIMARY KEY(NUMHOTEL),CONSTRAINT etoiles_ck CHECK (etoiles BETWEEN 0 AND 5))
NESTED TABLE hotel_chambre store as table_hotel_chambre,
NESTED TABLE hotel_evaluation store as table_hotel_evaluation;

CREATE TABLE Chambre OF tchambre(PRIMARY KEY(NUMCHAMBRE,NUMHOTEL), FOREIGN KEY(chambre_hotel) REFERENCES Hotel,
check(TYPECHAMBRE in ('simple', 'double', 'triple','suite','autre')) )
NESTED TABLE chambre_res store as table_chambre_res;

Create table client of tclient(PRIMARY KEY(NUMCLIENT))
NESTED TABLE client_eval store as table_client_eval,
NESTED TABLE client_res store as table_client_res;

Create table evaluation of tevaluation(PRIMARY KEY(NUMEVAL),FOREIGN KEY(eval_client) REFERENCES client,
FOREIGN KEY(eval_hotel) REFERENCES Hotel,CONSTRAINT noteck CHECK (note BETWEEN 0 AND 10));

Create table reservation of treservation(PRIMARY KEY(numres),FOREIGN KEY(res_client) REFERENCES client,
FOREIGN KEY(res_chambre) REFERENCES Chambre,CHECK(DATEARRIVEE<DATEDEPART));




SET LINESIZE 1500;
SET PAGESIZE 100;




--9.Lister les noms d’hôtels et leurs villes respectives.
SELECT H.NOMHOTEL AS NOM , H.VILLE AS VILLE FROM Hotel H;

--10. Lister les hôtels sur lesquels porte au moins une réservation.

select   H.NOMHOTEL, count(distinct r.column_value) as nb_reservation from hotel h, 
table(h.hotel_chambre) c, table(deref(c.column_value).chambre_res) r group by H.NOMHOTEL
having count(distinct r.column_value)>=1;

--11. Quels sont les clients qui ont toujours séjourné au premier étage ?
select c.NUMCLIENT,c.NOMCLIENT,C.PRENOMCLIENT, deref(deref(r.column_value).res_chambre).numchambre AS CHAMBRE FROM CLIENT C ,
TABLE(c.client_res) r where deref(deref(r.column_value).res_chambre).ETAGE=1;


--12.Quels sont les hôtels (nom, ville) qui offrent des suites ? et donner le prix pour chaque suite
SELECT H.NOMHOTEL AS NOM , H.VILLE AS VILLE, DEREF(r.column_value).PRIXNUIT AS PRIX
FROM Hotel H,table(h.hotel_chambre) r where DEREF(r.column_value).TYPECHAMBRE='suite' ;


--13. Quel est le type de chambre le plus réservé habituellement, pour chaque hôtel d’Alger ?
select c.TYPECHAMBRE as type,count(r.column_value )as nb from chambre c,table(c.chambre_res) r 
where deref(c.chambre_hotel).ville='Alger'
group by c.TYPECHAMBRE 
HAVING COUNT(r.COLUMN_VALUE) = (
    SELECT MAX(nb) FROM (
        SELECT  count(r2.column_value )as nb
        FROM CHAMBRE c2,
       table(c2.chambre_res) r2 
where deref(c2.chambre_hotel).ville='Alger'
group by c2.TYPECHAMBRE 
    ) 
);


--14. Quels sont les hôtels (nom, ville) ayant obtenu une moyenne de notes >=6, durant l’année 2022
SELECT H.NOMHOTEL AS NOM , H.VILLE AS VILLE  ,AVG(DEREF(eval.column_value).note) AS NOTEMOY
FROM Hotel H,table(h.hotel_evaluation) eval where DEREF(eval.column_value).datee<'01/01/2023'
 AND DEREF(eval.column_value).datee>'31/12/2021'
group by H.NOMHOTEL,H.VILLE
having AVG(DEREF(eval.column_value).note) >=6;


--15. Quel est l’hôtel ayant réalisé le meilleur chiffre d’affaire durant l’été 2022 (juin, juillet, aout, PS :
--compléter avec de nouvelles données de réservations).
select h.NOMHOTEL AS NOM_HOTEL,SUM(deref(c.column_value).calcul_chiffre())  from hotel h , table(h.hotel_chambre) c ,
 table(deref(c.column_value).chambre_res) r
Where deref(r.column_value).DATEARRIVEE>='01/06/2022' AND deref(r.column_value).DATEDEPART<='31/08/2022'
group by h.NOMHOTEL
HAVING SUM(deref(c.column_value).calcul_chiffre())  = (
    SELECT MAX(CA) FROM (
      SELECT   SUM(deref(c2.column_value).calcul_chiffre()) AS CA from hotel h , table(h.hotel_chambre) c2 ,
 table(deref(c2.column_value).chambre_res) r2
Where deref(r2.column_value).DATEARRIVEE>='01/06/2022' AND deref(r2.column_value).DATEDEPART<='31/08/2022'
group by h.NOMHOTEL
    ) 
);



