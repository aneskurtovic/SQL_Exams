--------------------------------------------------------------------

-- 1. a) Kreirati bazu pod vlastitim brojem indeksa.

CREATE DATABASE IB160061_Sept
GO
USE IB160061_Sept

/*
1. b) Kreiranje tabela.
Prilikom kreiranja tabela voditi računa o odnosima između tabela.
I. Kreirati tabelu narudzba sljedeće strukture:
	narudzbaID, cjelobrojna varijabla, primarni ključ
	dtm_narudzbe, datumska varijabla za unos samo datuma
	dtm_isporuke, datumska varijabla za unos samo datuma
	prevoz, novčana varijabla
	klijentID, 5 unicode karaktera
	klijent_naziv, 40 unicode karaktera
	prevoznik_naziv, 40 unicode karaktera
*/

CREATE TABLE Narudzba
(
	narudzbaID INT CONSTRAINT pk_Narudzba PRIMARY KEY(narudzbaID),
	dtm_narudzbe DATE,
	dtm_isporuke DATE,
	prevoz MONEY,
	klijentID NVARCHAR(5),
	klijent_naziv NVARCHAR(40),
	prevoznik_naziv NVARCHAR(40)
)

/*
II. Kreirati tabelu proizvod sljedeće strukture:
	- proizvodID, cjelobrojna varijabla, primarni ključ
	- mj_jedinica, 20 unicode karaktera
	- jed_cijena, novčana varijabla
	- kateg_naziv, 15 unicode karaktera
	- dobavljac_naziv, 40 unicode karaktera
	- dobavljac_web, tekstualna varijabla
*/

CREATE TABLE Proizvod
(
	proizvodID INT CONSTRAINT pk_proizvod PRIMARY KEY(proizvodID),
	mj_jedinica NVARCHAR(20),
	jed_cijena MONEY,
	kateg_naziv NVARCHAR(15),
	dobavljac_naziv NVARCHAR(40),
	dobavljac_web TEXT
)

/*
III. Kreirati tabelu narudzba_proizvod sljedeće strukture:
	- narudzbaID, cjelobrojna varijabla, obavezan unos
	- proizvodID, cjelobrojna varijabla, obavezan unos
	- uk_cijena, novčana varijabla
*/

CREATE TABLE Narudzba_Proizvod
(
	narudzbaID INT NOT NULL,
	proizvodID INT NOT NULL,
	uk_cijena MONEY,
	CONSTRAINT pk_narpro PRIMARY KEY(narudzbaID, proizvodID),
	CONSTRAINT fk_narudzba FOREIGN KEY(narudzbaID) REFERENCES Narudzba(narudzbaID),
	CONSTRAINT fk_proizvod FOREIGN KEY(proizvodID) REFERENCES Proizvod(proizvodID)
)

--------------------------------------------------------------------

/*
2. Import podataka
a) Iz tabela Customers, Orders i Shipers baze Northwind importovati podatke prema pravilu:
	- OrderID -> narudzbaID
	- OrderDate -> dtm_narudzbe
	- ShippedDate -> dtm_isporuke
	- Freight -> prevoz
	- CustomerID -> klijentID
	- CompanyName -> klijent_naziv
	- CompanyName -> prevoznik_naziv
*/

INSERT INTO Narudzba
SELECT O.OrderID, O.OrderDate, O.ShippedDate, O.Freight, C.CustomerID, C.CompanyName, S.CompanyName
FROM Northwind.dbo.Customers AS C INNER JOIN Northwind.dbo.Orders AS O
	ON C.CustomerID = O.CustomerID INNER JOIN Northwind.dbo.Shippers AS S
	ON S.ShipperID = O.ShipVia

/*
b) Iz tabela Categories, Product i Suppliers baze Northwind importovati podatke prema pravilu:
	- ProductID -> proizvodID
	- QuantityPerUnit -> mj_jedinica
	- UnitPrice -> jed_cijena
	- CategoryName -> kateg_naziv
	- CompanyName -> dobavljac_naziv
	- HomePage -> dobavljac_web
*/

INSERT INTO Proizvod
SELECT P.ProductID, P.QuantityPerUnit, P.UnitPrice, C.CategoryName, S.CompanyName, S.HomePage
FROM Northwind.dbo.Categories AS C INNER JOIN Northwind.dbo.Products AS P
	 ON C.CategoryID = P.CategoryID INNER JOIN Northwind.dbo.Suppliers AS S
	 ON S.SupplierID = P.SupplierID

/*
c) Iz tabele Order Details baze Northwind importovati podatke prema pravilu:
	- OrderID -> narudzbaID
	- ProductID -> proizvodID
	- uk_cijena <- proizvod jedinične cijene i količine
uz uslov da nije odobren popust na proizvod.
*/

INSERT INTO Narudzba_Proizvod
SELECT OD.OrderID, OD.ProductID, OD.UnitPrice * OD.Quantity AS uk_cijena
FROM Northwind.dbo.[Order Details] AS OD
WHERE OD.Discount=0

--------------------------------------------------------------------

/*
3. 
Koristeći tabele proizvod i narudzba_proizvod kreirati pogled view_kolicina koji će imati strukturu:
	- proizvodID
	- kateg_naziv
	- jed_cijena
	- uk_cijena
	- kolicina - količnik ukupne i jedinične cijene
U pogledu trebaju biti samo oni zapisi kod kojih količina ima smisao (nije moguće da je na stanju 1,23 proizvoda).
Obavezno pregledati sadržaj pogleda.
*/

CREATE VIEW view_kolicina AS
SELECT P.proizvodID, P.kateg_naziv, P.jed_cijena, NP.uk_cijena, (NP.uk_cijena / P.jed_cijena) AS kolicina
FROM Narudzba_Proizvod AS NP INNER JOIN Proizvod AS P
	 ON NP.proizvodID = P.proizvodID
WHERE (NP.uk_cijena / P.jed_cijena)%1=0


SELECT * FROM view_kolicina 

--------------------------------------------------------------------

/*
4. 
Koristeći pogled kreiran u 3. zadatku kreirati proceduru tako da je prilikom izvršavanja moguće unijeti bilo koji broj parametara 
(možemo ostaviti bilo koji parametar bez unijete vrijednosti). Proceduru pokrenuti za sljedeće nazive kategorija:
1. Produce
2. Beverages
*/

CREATE PROCEDURE proc_kolicina
(
	@proizvodID INT = NULL,
	@kateg_naziv NVARCHAR(15) = NULL,
	@jed_cijena MONEY=NULL,
	@uk_cijena MONEY=NULL,
	@kolicina DECIMAL(5,2) = NULL
)
AS
BEGIN
	SELECT proizvodID, kateg_naziv, jed_cijena, uk_cijena, kolicina
	FROM view_kolicina
	WHERE proizvodID = @proizvodID OR
		  kateg_naziv = @kateg_naziv OR
		  jed_cijena = @jed_cijena OR
		  uk_cijena = @uk_cijena OR
		  kolicina = @kolicina
END

EXEC proc_kolicina @kateg_naziv = 'Produce'

EXEC proc_kolicina @kateg_naziv = 'Beverages'

--------------------------------------------------------------------

/*
5.
Koristeći pogled kreiran u 3. zadatku kreirati proceduru proc_br_kat_naziv koja će vršiti prebrojavanja po nazivu kategorije. Nakon kreiranja pokrenuti proceduru.
*/

CREATE PROCEDURE proc_prebrojavanje AS
BEGIN
	SELECT kateg_naziv, COUNT(kateg_naziv)
	FROM view_kolicina
	GROUP BY kateg_naziv
END

EXEC proc_prebrojavanje

--------------------------------------------------------------------

/*
6.
a) Iz tabele narudzba_proizvod kreirati pogled view_suma sljedeće strukture:
	- narudzbaID
	- suma - sume ukupne cijene po ID narudžbe
Obavezno napisati naredbu za pregled sadržaja pogleda.*/

CREATE VIEW view_suma AS
SELECT narudzbaID, SUM(uk_cijena) AS suma
FROM Narudzba_Proizvod
GROUP BY narudzbaID

SELECT * FROM view_suma

-- 6.b) Napisati naredbu kojom će se prikazati srednja vrijednost sume zaokružena na dvije decimale.

SELECT ROUND(AVG(suma),2)
FROM view_suma

-- 6.c) Iz pogleda kreiranog pod a) dati pregled zapisa čija je suma veća od prosječne sume. Osim kolona iz pogleda, potrebno je prikazati razliku sume i srednje vrijednosti. Razliku zaokružiti na dvije decimale.

SELECT narudzbaID, suma, suma - (SELECT ROUND(AVG(suma),2) FROM view_suma) AS razlika
FROM view_suma
WHERE suma > (SELECT avg(suma) FROM view_suma)

--------------------------------------------------------------------

/*
7.
a) U tabeli narudzba dodati kolonu evid_br, 30 unicode karaktera 
b) Kreirati proceduru kojom će se izvršiti punjenje kolone evid_br na sljedeći način:
	- ako u datumu isporuke nije unijeta vrijednost, evid_br se dobija generisanjem slučajnog niza znakova
	- ako je u datumu isporuke unijeta vrijednost, evid_br se dobija spajanjem datum narudžbe i datuma isprouke uz umetanje donje crte između datuma
Nakon kreiranja pokrenuti proceduru.
Obavezno provjeriti sadržaj tabele narudžba.
*/

ALTER TABLE Narudzba
ADD evid_br NVARCHAR(30)

CREATE PROCEDURE proc_evidbr AS
BEGIN
	UPDATE Narudzba
	SET evid_br = LEFT(NEWID(),30)
	WHERE dtm_isporuke IS NULL
	UPDATE Narudzba
	SET evid_br = CONVERT(NVARCHAR,dtm_isporuke) + '-' + CONVERT(NVARCHAR,dtm_narudzbe)
	WHERE dtm_isporuke IS NOT NULL
END

EXEC proc_evidbr

SELECT * FROM Narudzba

--------------------------------------------------------------------

/*
8. Kreirati proceduru kojom će se dobiti pregled sljedećih kolona:
	- narudzbaID,
	- klijent_naziv,
	- proizvodID,
	- kateg_naziv,
	- dobavljac_naziv
Uslov je da se dohvate samo oni zapisi u kojima naziv kategorije sadrži samo 1 riječ.
Pokrenuti proceduru.
*/

CREATE PROCEDURE proc_kateg_rijec AS
BEGIN
	SELECT N.narudzbaID, N.klijent_naziv, P.proizvodID, P.kateg_naziv, P.dobavljac_naziv
	FROM Narudzba AS N INNER JOIN Narudzba_Proizvod AS NP
		 ON N.narudzbaID = NP.narudzbaID INNER JOIN Proizvod AS P
		 ON P.proizvodID = NP.proizvodID
	WHERE CHARINDEX(' ', P.kateg_naziv) = 0 AND CHARINDEX('/', P.kateg_naziv) = 0
END

EXEC proc_kateg_rijec

--------------------------------------------------------------------

/*
9.
U tabeli proizvod izvršiti update kolone dobavljac_web tako da se iz kolone dobavljac_naziv uzme prva riječ, 
a zatim se formira web adresa u formi www.prva_rijec.com. Update izvršiti pomoću dva upita, vodeći računa o broju riječi u nazivu. 
*/

-- jedna rijec

UPDATE Proizvod
SET dobavljac_web='www.'+dobavljac_naziv+'.com'
WHERE (CHARINDEX(' ',dobavljac_naziv)-1) < 0

-- vise rijeci

UPDATE Proizvod
SET dobavljac_web='www.'+LEFT(dobavljac_naziv, (CHARINDEX(' ',dobavljac_naziv)-1))+'.com'
WHERE (CHARINDEX(' ',dobavljac_naziv)-1) >= 0

-- provjera

SELECT * FROM Proizvod

--------------------------------------------------------------------

/*
10.
a) Kreirati backup baze na default lokaciju.
b) Kreirati proceduru kojom će se u jednom izvršavanju obrisati svi pogledi i procedure u bazi. Pokrenuti proceduru.
*/

BACKUP DATABASE IB160061_Sept
TO DISK = 'IB160061_Sept.bak'

CREATE PROCEDURE proc_delete AS
BEGIN
	DROP VIEW view_kolicina, view_suma
	DROP PROCEDURE proc_evidbr, proc_kateg_rijec, proc_prebrojavanje, proc_kolicina
END

EXEC proc_delete
