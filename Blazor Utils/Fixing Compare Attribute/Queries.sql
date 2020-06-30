SELECT * FROM Employees e
SELECT * FROM Departments d

TRUNCATE TABLE Employees;
DBCC CHECKIDENT('Employees', RESEED, 1);
INSERT INTO Employees (FirstName, LastName, Email, DateOfBirth, Gender, DepartmentId, PhotoPath) 
  VALUES ('Sam', 'Galloway', 'sam@test.com', CONVERT(DATETIME2, '22-12-1981', 105), 0, 2, 'images/sam.jpg');
INSERT INTO Employees (FirstName, LastName, Email, DateOfBirth, Gender, DepartmentId, PhotoPath) 
  VALUES ('Mary', 'Smith', 'mary@test.com', CONVERT(DATETIME2, '11-11-1979', 105), 1, 1, 'images/mary.png');
INSERT INTO Employees (FirstName, LastName, Email, DateOfBirth, Gender, DepartmentId, PhotoPath) 
  VALUES ('Sara', 'Longway', 'sara@test.com', CONVERT(DATETIME2, '23-09-1982', 105), 1, 3, 'images/sara.png');
INSERT INTO Employees (FirstName, LastName, Email, DateOfBirth, Gender, DepartmentId, PhotoPath) 
  VALUES ('John', 'Galloway', 'john@test.com', CONVERT(DATETIME2, '16-05-1987', 105), 0, 2, 'images/john.png');
INSERT INTO Employees (FirstName, LastName, Email, DateOfBirth, Gender, DepartmentId, PhotoPath) 
  VALUES ('Rob', 'Hastings', 'rob@test.com', CONVERT(DATETIME2, '20-05-1990', 105), 0, 1, 'images/nophoto.jpg');
SELECT * FROM Employees e