create table Customers(
	customer_id int  primary key identity (1,1),
	f_name  varchar (50),
	L_name varchar(50),
	gender varchar(2) check (gender in ('M','F')),
	national_id varchar(20) not null unique,
	email varchar(50) unique,
	city varchar(50),
	street varchar(50),
	Registration_Date date , 
	Card_num varchar(20),
);

create table SIM_Card (
    SIM_ID int identity(1,1) primary key,
    SIM_Number varchar(20)  not null,
    Status varchar(20)  not null,
    ActivationDate date  not null,
    CustomerID int  not null,
    constraint FK_SIM_Customer foreign key (CustomerID) references Customers(customer_id)
);



create table Department (
    department_id int primary key identity(1,1),
    department_name varchar(50) not null unique,
	manager_id int,
);


create table Employee(
	employee_id int primary key identity (1,1),
	department_id int,
	f_name varchar(50),
	L_name varchar(50),
	salary float,
	constraint FK_Employee_Department foreign key (department_id) references Department(department_id)
);

alter table Department
add constraint FK_Department_Manager foreign key (Manager_ID) references Employee(employee_id)


create table Complaint (
    Complaint_ID int primary key identity (1,5),
    ComplaintDate date,
    IssueType varchar(100),
    Status varchar(30),
    CustomerID int,
    EmployeeID int,
    constraint FK_Complaint_Customer foreign key (CustomerID)references Customers(customer_id),
    constraint FK_Complaint_Employee foreign key (EmployeeID)references Employee(employee_id)
);


create table ServicePlan(
	plan_id int primary key identity (1,1),
	plan_name varchar(50),
	monthly_fee float,
	minutes_limit int,
	data_limit 	int,
	sms_limit int,
);


create table Subscription(
	subscription_id int primary key identity  (1,1),
	SIM_ID int not null,
	start_date date,
	end_date date,
	status varchar(30) check (status IN ('active', 'suspended', 'Cancelled')),
	plan_id int not null,
	constraint FK_Subscription_SIM_Card foreign key(SIM_ID)  references SIM_Card(SIM_ID),
	constraint FK_Subscription_Plan foreign key(Plan_id) references ServicePlan(plan_id)
);


CREATE TABLE Usage_Records(
	usage_id int primary key identity (1,1),
	subscription_id int,
	usage_date date,
	minutes_used int,
	data_used int,
	sms_used int,
	constraint FK_Usage_Subscription foreign key(subscription_id) references Subscription(subscription_id)
);



CREATE TABLE Payment (
    payment_id int identity(1,1) primary key,
    subscription_id int  not null,
    payment_amount decimal(10,2)  not null,
    payment_date date  not null,
    payment_method varchar(30)  not null,
    constraint FK_Payment_Subscription foreign key (subscription_id) references Subscription(subscription_id)
);


